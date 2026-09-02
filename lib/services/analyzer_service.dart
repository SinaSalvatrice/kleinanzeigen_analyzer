import '../models/listing_draft.dart';

class AnalyzerService {
  Future<ListingDraft> analyze(ListingDraft input) async {
    // MVP scaffold: replace this with image understanding + web research.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final subject = [input.brand.trim(), input.model.trim()]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
    final fallback = input.notes.trim().isEmpty ? 'Artikel' : input.notes.trim();
    final name = subject.isEmpty ? fallback : subject;

    return ListingDraft(
      title: name.length > 65 ? name.substring(0, 65) : name,
      description: _buildDescription(name, input),
      category: input.category,
      condition: input.condition,
      notes: input.notes,
      brand: input.brand,
      model: input.model,
      priceFast: 20,
      priceRealistic: 30,
      priceListing: 35,
      confidence: 0.25,
      imagePaths: List<String>.from(input.imagePaths),
    );
  }

  String _buildDescription(String name, ListingDraft input) {
    final buffer = StringBuffer()
      ..writeln(name)
      ..writeln();

    if (input.condition.trim().isNotEmpty) {
      buffer.writeln('Zustand: ${input.condition.trim()}');
    }
    if (input.notes.trim().isNotEmpty) {
      buffer.writeln(input.notes.trim());
    }

    buffer
      ..writeln()
      ..writeln('Privatverkauf. Angaben bitte vor Veröffentlichung prüfen.');
    return buffer.toString().trim();
  }
}
