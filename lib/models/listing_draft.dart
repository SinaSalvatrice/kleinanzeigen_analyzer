class ListingDraft {
  ListingDraft({
    this.title = '',
    this.description = '',
    this.category = '',
    this.condition = '',
    this.notes = '',
    this.brand = '',
    this.model = '',
    this.priceFast,
    this.priceRealistic,
    this.priceListing,
    this.confidence = 0,
    this.identification = '',
    this.researchSummary = '',
    List<String>? imagePaths,
    List<ResearchSource>? sources,
  })  : imagePaths = imagePaths ?? <String>[],
        sources = sources ?? <ResearchSource>[];

  String title;
  String description;
  String category;
  String condition;
  String notes;
  String brand;
  String model;
  double? priceFast;
  double? priceRealistic;
  double? priceListing;
  double confidence;
  String identification;
  String researchSummary;
  final List<String> imagePaths;
  final List<ResearchSource> sources;

  bool get hasPriceEstimate =>
      priceFast != null && priceRealistic != null && priceListing != null;
}

class ResearchSource {
  ResearchSource({
    required this.title,
    required this.url,
    this.price,
    this.note = '',
  });

  final String title;
  final String url;
  final double? price;
  final String note;
}
