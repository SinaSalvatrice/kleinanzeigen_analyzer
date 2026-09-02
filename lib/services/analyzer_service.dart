import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/listing_draft.dart';

class AnalyzerService {
  AnalyzerService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ListingDraft> analyze(ListingDraft input) async {
    try {
      return await _analyzeInternal(input);
    } catch (error) {
      return ListingDraft(
        title: 'Analysefehler',
        description: 'Die Analyse konnte nicht ausgeführt werden.\n\n${_friendlyError(error)}',
        category: input.category,
        condition: input.condition,
        notes: input.notes,
        brand: input.brand,
        model: input.model,
        confidence: 0,
        identification: 'Analyse fehlgeschlagen',
        researchSummary: _friendlyError(error),
        imagePaths: List<String>.from(input.imagePaths),
      );
    }
  }

  Future<ListingDraft> _analyzeInternal(ListingDraft input) async {
    final apiKey = Platform.environment['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError(
        'OPENAI_API_KEY fehlt. Die App muss aus demselben PowerShell-Fenster gestartet werden, in dem der Key gesetzt wurde.',
      );
    }

    final content = <Map<String, dynamic>>[
      {
        'type': 'input_text',
        'text': _buildPrompt(input),
      },
    ];

    var usableImages = 0;
    for (final imagePath in input.imagePaths.take(8)) {
      final extension = p.extension(imagePath).toLowerCase();
      if (!{'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)) {
        continue;
      }

      final file = File(imagePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      content.add({
        'type': 'input_image',
        'image_url': 'data:${_mimeType(imagePath)};base64,${base64Encode(bytes)}',
        'detail': 'high',
      });
      usableImages++;
    }

    if (usableImages == 0 &&
        input.brand.trim().isEmpty &&
        input.model.trim().isEmpty &&
        input.notes.trim().isEmpty) {
      throw StateError(
        'Es fehlen verwertbare Eingaben. Bitte mindestens ein JPG/PNG/WebP-Foto oder Angaben zum Gegenstand hinzufügen.',
      );
    }

    final response = await _client
        .post(
          Uri.parse('https://api.openai.com/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-5.6-terra',
            'tools': [
              {'type': 'web_search'}
            ],
            'input': [
              {
                'role': 'user',
                'content': content,
              }
            ],
            'text': {
              'format': {
                'type': 'json_schema',
                'name': 'kleinanzeigen_analysis',
                'strict': true,
                'schema': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'identification': {'type': 'string'},
                    'brand': {'type': 'string'},
                    'model': {'type': 'string'},
                    'category': {'type': 'string'},
                    'condition': {'type': 'string'},
                    'confidence': {'type': 'number'},
                    'price_fast': {'type': 'number'},
                    'price_realistic': {'type': 'number'},
                    'price_listing': {'type': 'number'},
                    'title': {'type': 'string'},
                    'description': {'type': 'string'},
                    'research_summary': {'type': 'string'},
                    'sources': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'title': {'type': 'string'},
                          'url': {'type': 'string'},
                          'price': {'type': ['number', 'null']},
                          'note': {'type': 'string'},
                        },
                        'required': ['title', 'url', 'price', 'note'],
                      },
                    },
                  },
                  'required': [
                    'identification',
                    'brand',
                    'model',
                    'category',
                    'condition',
                    'confidence',
                    'price_fast',
                    'price_realistic',
                    'price_listing',
                    'title',
                    'description',
                    'research_summary',
                    'sources',
                  ],
                },
              }
            },
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _apiErrorMessage(response.body);
      throw HttpException(
        'OpenAI API ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final outputText = _extractOutputText(payload);
    if (outputText == null || outputText.trim().isEmpty) {
      throw const FormatException(
        'Die API hat geantwortet, aber kein auswertbares Analyse-Ergebnis geliefert.',
      );
    }

    final data = jsonDecode(outputText) as Map<String, dynamic>;
    final sources = (data['sources'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (source) => ResearchSource(
            title: source['title']?.toString() ?? '',
            url: source['url']?.toString() ?? '',
            price: (source['price'] as num?)?.toDouble(),
            note: source['note']?.toString() ?? '',
          ),
        )
        .toList();

    return ListingDraft(
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      category: data['category']?.toString() ?? input.category,
      condition: data['condition']?.toString() ?? input.condition,
      notes: input.notes,
      brand: data['brand']?.toString() ?? input.brand,
      model: data['model']?.toString() ?? input.model,
      priceFast: (data['price_fast'] as num?)?.toDouble(),
      priceRealistic: (data['price_realistic'] as num?)?.toDouble(),
      priceListing: (data['price_listing'] as num?)?.toDouble(),
      confidence: ((data['confidence'] as num?)?.toDouble() ?? 0.0)
          .clamp(0.0, 1.0)
          .toDouble(),
      identification: data['identification']?.toString() ?? '',
      researchSummary: data['research_summary']?.toString() ?? '',
      imagePaths: List<String>.from(input.imagePaths),
      sources: sources,
    );
  }

  String _buildPrompt(ListingDraft input) {
    return '''
Du analysierst einen gebrauchten Gegenstand für ein deutsches Kleinanzeigen-Inserat.

Ziele:
1. Identifiziere den Gegenstand anhand der Bilder und Nutzereingaben. Hersteller/Modell nur nennen, wenn ausreichend belegt; Unsicherheit offen benennen.
2. Recherchiere aktuelle Vergleichsangebote im Web, bevorzugt Deutschland. Berücksichtige Kleinanzeigen, eBay und spezialisierte Marktplätze. Aktive Angebotspreise sind keine Verkaufspreise; behandle sie entsprechend vorsichtig.
3. Leite drei EUR-Preise ab: price_fast = schneller Verkauf, price_realistic = realistischer Marktpreis, price_listing = sinnvoller Startpreis/VB.
4. confidence ist 0 bis 1 und bewertet Identifikation plus Preisbasis.
5. Erstelle einen sachlichen, suchbaren Kleinanzeigen-Titel und eine knappe deutsche Beschreibung. Keine erfundenen Eigenschaften. Keine Garantiebehauptungen.
6. Gib nur tatsächlich verwendete Quellen mit URL zurück; pro Quelle kurz erklären, warum sie vergleichbar oder nur eingeschränkt vergleichbar ist.

Vom Nutzer bekannte Angaben:
Hersteller: ${input.brand.trim().isEmpty ? 'unbekannt' : input.brand.trim()}
Modell/Typ: ${input.model.trim().isEmpty ? 'unbekannt' : input.model.trim()}
Kategorie: ${input.category.trim().isEmpty ? 'unbekannt' : input.category.trim()}
Zustand: ${input.condition.trim().isEmpty ? 'nicht angegeben' : input.condition.trim()}
Notizen/Maße/Lieferumfang: ${input.notes.trim().isEmpty ? 'keine' : input.notes.trim()}

Wichtig: Sichtbare Schäden dürfen beschrieben werden, aber Funktionsfähigkeit niemals allein aus einem Foto ableiten. Falls keine belastbaren Vergleichspreise gefunden werden, senke confidence deutlich und sage das in research_summary.
''';
  }

  String? _extractOutputText(Map<String, dynamic> payload) {
    final output = payload['output'];
    if (output is! List) return null;
    for (final item in output) {
      if (item is! Map<String, dynamic> || item['type'] != 'message') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is Map<String, dynamic> && part['type'] == 'output_text') {
          return part['text']?.toString();
        }
      }
    }
    return null;
  }

  String _apiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          return error['message']?.toString() ?? '';
        }
      }
    } catch (_) {
      // Fall back to a shortened raw response below.
    }
    final trimmed = body.trim();
    if (trimmed.length <= 500) return trimmed;
    return '${trimmed.substring(0, 500)}…';
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'Zeitüberschreitung nach 90 Sekunden. Internetverbindung bzw. API erneut prüfen.';
    }
    if (error is SocketException) {
      return 'Keine Verbindung zur API: ${error.message}';
    }
    if (error is StateError) {
      return error.message;
    }
    if (error is HttpException) {
      return error.message;
    }
    if (error is FormatException) {
      return 'Antwortformat ungültig: ${error.message}';
    }
    return '$error';
  }

  String _mimeType(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
