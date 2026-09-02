import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'models/listing_draft.dart';
import 'services/analyzer_service.dart';

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
  final _analyzer = AnalyzerService();

  final List<String> _images = <String>[];
  ListingDraft? _result;
  bool _dragging = false;
  bool _analyzing = false;

  static const _extensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  };

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kleinanzeigen Analyzer'),
        actions: [
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
            _field(_categoryController, 'Kategorie', 'z. B. Elektrowerkzeug'),
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
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titel'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 9,
                maxLines: 16,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
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
                        'MVP-Platzhalter: Webquellen und echte Vergleichsangebote werden im nächsten Schritt angeschlossen.\nConfidence aktuell: ${(_result!.confidence * 100).round()} %',
                      ),
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
