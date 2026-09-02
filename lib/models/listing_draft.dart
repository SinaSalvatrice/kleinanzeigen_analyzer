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
    List<String>? imagePaths,
  }) : imagePaths = imagePaths ?? <String>[];

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
  final List<String> imagePaths;

  bool get hasPriceEstimate =>
      priceFast != null && priceRealistic != null && priceListing != null;
}
