import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'models/listing_draft.dart';
import 'services/analyzer_service.dart';
import 'services/api_key_service.dart';

void main() {
  runApp(const KleinanzeigenAnalyzerApp());
}

class KleinanzeigenAnalyzerApp extends StatelessWidget {
  const KleinanzeigenAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kleinanzeigen Analyzer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C6E5A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101313),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const AnalyzerHomePage(),
    );
  }
}

class AnalyzerHomePage extends StatefulWidget {
  const AnalyzerHomePage({super.key});

  @override
  State<AnalyzerHomePage> createState() => _AnalyzerHomePageState();
}

class _AnalyzerHomePageState extends State<AnalyzerHomePage> {
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _categoryController = TextEditingController();
  final _conditionController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiKeyService = ApiKeyService();
  late final AnalyzerService _analyzer = AnalyzerService(
    apiKeyService: _apiKeyService,
  );

  final List<String> _images = <String>[];
  ListingDraft? _result;
  bool _dragging = false;
  bool _analyzing = false;
  bool _apiKeyAvailable = false;

  static const _extensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  @override
  void initState() {
    super.initState();
    _refreshApiKeyState();
  }

  Future<void> _refreshApiKeyState() async {
    final key = await _apiKeyService.read();
    if (!mounted) return;
    setState(() => _apiKeyAvailable = key != null && key.isNotEmpty);
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    _notesController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;
    _addImages(result.paths.whereType<String>());
  }

  void _addImages(Iterable<String> paths) {
    final valid = paths.where(
      (path) => _extensions.contains(p.extension(path).toLowerCase()),
    );
    setState(() {
      for (final path in valid) {
        if (!_images.contains(path)) _images.add(path);
      }
    });
  }

  Future<void> _analyze() async {
    final key = await _apiKeyService.read();
    if (key == null || key.isEmpty) {
      if (mounted) await _showApiKeyDialog();
      return;
    }

    setState(() => _analyzing = true);
    try {
      final draft = ListingDraft(
        brand: _brandController.text,
        model: _modelController.text,
        category: _categoryController.text,
        condition: _conditionController.text,
        notes: _notesController.text,
        imagePaths: List<String>.from(_images),
      );
      final result = await _analyzer.analyze(draft);
      if (!mounted) return;
      setState(() {
        _result = result;
        _titleController.text = result.title;
        _descriptionController.text = result.description;
      });
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _showApiKeyDialog() async {
    final existing = await _apiKeyService.read() ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: existing);
    var obscure = true;
    var testing = false;
    String? statusMessage;
    bool? statusOk;

    await showDialog<void>(
      context: context,
      barrierDismissible: !testing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> testKey() async {
              final cleaned = _apiKeyService.sanitize(controller.text);
              controller.value = controller.value.copyWith(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );

              setDialogState(() {
                testing = true;
                statusMessage = 'Verbindung wird geprüft …';
                statusOk = null;
              });

              final result = await _apiKeyService.test(cleaned);
              if (!context.mounted) return;
              setDialogState(() {
                testing = false;
                statusMessage = result.message;
                statusOk = result.ok;
              });
            }

            Future<void> saveKey() async {
              try {
                final cleaned = _apiKeyService.sanitize(controller.text);
                await _apiKeyService.save(cleaned);
                await _refreshApiKeyState();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('API-Key sicher gespeichert.')),
                );
              } on FormatException catch (error) {
                setDialogState(() {
                  statusMessage = error.message;
                  statusOk = false;
                });
              } catch (error) {
                setDialogState(() {
                  statusMessage = 'Speichern fehlgeschlagen: $error';
                  statusOk = false;
                });
              }
            }

            Future<void> deleteKey() async {
              await _apiKeyService.delete();
              await _refreshApiKeyState();
              if (!context.mounted) return;
              controller.clear();
              setDialogState(() {
                statusMessage = 'Gespeicherter API-Key wurde entfernt.';
                statusOk = null;
              });
            }

            return AlertDialog(
              title: const Text('OpenAI API'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Füge deinen OpenAI API-Key hier ein. Zeilenumbrüche und Leerzeichen werden automatisch entfernt.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      obscureText: obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) {
                        if (statusMessage != null) {
                          setDialogState(() {
                            statusMessage = null;
                            statusOk = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'OpenAI API-Key',
                        hintText: 'sk-…',
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Key anzeigen' : 'Key verbergen',
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: testing
                              ? null
                              : () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  final cleaned = _apiKeyService.sanitize(
                                    data?.text ?? '',
                                  );
                                  controller.value = TextEditingValue(
                                    text: cleaned,
                                    selection: TextSelection.collapsed(
                                      offset: cleaned.length,
                                    ),
                                  );
                                  setDialogState(() {
                                    statusMessage = null;
                                    statusOk = null;
                                  });
                                },
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Einfügen'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: testing ? null : deleteKey,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Entfernen'),
                        ),
                      ],
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (testing)
                              const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                statusOk == true
                                    ? Icons.check_circle_outline
                                    : statusOk == false
                                        ? Icons.error_outline
                                        : Icons.info_outline,
                                size: 20,
                              ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(statusMessage!)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Der Key wird lokal im sicheren Systemspeicher abgelegt und nicht im GitHub-Repository gespeichert.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: testing
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Schließen'),
                ),
                OutlinedButton.icon(
                  onPressed: testing ? null : testKey,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Verbindung testen'),
                ),
                FilledButton.icon(
                  onPressed: testing ? null : saveKey,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    await _refreshApiKeyState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Kleinanzeigen Analyzer'),
            SizedBox(width: 10),
            Text('v0.3', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _showApiKeyDialog,
              icon: Icon(
                _apiKeyAvailable ? Icons.key : Icons.key_off_outlined,
              ),
              label: Text(_apiKeyAvailable ? 'API bereit' : 'API-Key'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _analyzing ? null : _analyze,
              icon: _analyzing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_analyzing ? 'Analysiere …' : 'Analysieren'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 4, child: _buildImagesPanel()),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildFactsPanel()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildResultPanel()),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(height: 420, child: _buildImagesPanel()),
              const SizedBox(height: 16),
              _buildFactsPanel(),
              const SizedBox(height: 16),
              _buildResultPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesPanel() {
    return _panel(
      title: '1. Fotos',
      child: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (details) {
          setState(() => _dragging = false);
          _addImages(details.files.map((file) => file.path));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            border: Border.all(
              color: _dragging
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: _dragging ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _images.isEmpty
                          ? 'Bilder hier hineinziehen'
                          : '${_images.length} Bild${_images.length == 1 ? '' : 'er'} geladen',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Auswählen'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _images.isEmpty
                    ? const Center(
                        child: Text(
                          'Mehrere Ansichten, Typenschilder und Zubehör mit fotografieren.\nDas verbessert Identifikation und Preisrecherche.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          final path = _images[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 5,
                                top: 5,
                                child: IconButton.filledTonal(
                                  tooltip: 'Entfernen',
                                  onPressed: () =>
                                      setState(() => _images.removeAt(index)),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFactsPanel() {
    return _panel(
      title: '2. Was weißt du schon?',
      child: SingleChildScrollView(
        child: Column(
          children: [
            _field(_brandController, 'Hersteller', 'z. B. Bosch'),
            const SizedBox(height: 12),
            _field(_modelController, 'Modell / Typ', 'z. B. PSB 500 RE'),
            const SizedBox(height: 12),
            _field(
              _categoryController,
              'Kategorie',
              'z. B. Elektrowerkzeug',
            ),
            const SizedBox(height: 12),
            _field(
              _conditionController,
              'Zustand',
              'z. B. gebraucht, getestet, funktioniert',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Notizen / Maße / Lieferumfang',
                hintText:
                    'Alles reinschreiben, was die KI nicht zuverlässig aus Bildern wissen kann.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _analyzing ? null : _analyze,
                icon: const Icon(Icons.search),
                label: const Text('Identifizieren & Preis recherchieren'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _buildResultPanel() {
    return _panel(
      title: '3. Ergebnis',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_result == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.manage_search, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Noch keine Analyse.\nHier landen Identifikation, Vergleichspreise und das fertige Listing.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              _priceCards(_result!),
              const SizedBox(height: 16),
              if (_result!.identification.isNotEmpty) ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Identifikation',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_result!.identification),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence: ${(_result!.confidence * 100).round()} %',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titel',
                  suffixIcon: IconButton(
                    tooltip: 'Titel kopieren',
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _titleController.text),
                    ),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 9,
                maxLines: 16,
                decoration: InputDecoration(
                  labelText: 'Beschreibung',
                  suffixIcon: IconButton(
                    tooltip: 'Beschreibung kopieren',
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _descriptionController.text),
                    ),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recherche',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result!.researchSummary.isEmpty
                            ? 'Keine Recherche-Zusammenfassung vorhanden.'
                            : _result!.researchSummary,
                      ),
                      if (_result!.sources.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 6),
                        ..._result!.sources.map(
                          (source) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.price == null
                                      ? source.title
                                      : '${source.title} — ${source.price!.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (source.note.isNotEmpty) Text(source.note),
                                if (source.url.isNotEmpty)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          source.url,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'URL kopieren',
                                        onPressed: () => Clipboard.setData(
                                          ClipboardData(text: source.url),
                                        ),
                                        icon: const Icon(
                                          Icons.copy_outlined,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceCards(ListingDraft result) {
    String money(double? value) => value == null
        ? '–'
        : '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} €';

    return Row(
      children: [
        Expanded(child: _metric('Schnell', money(result.priceFast))),
        const SizedBox(width: 8),
        Expanded(child: _metric('Realistisch', money(result.priceRealistic))),
        const SizedBox(width: 8),
        Expanded(child: _metric('Inserat', money(result.priceListing))),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
