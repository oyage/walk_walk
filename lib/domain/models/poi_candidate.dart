/// POI（Point of Interest）候補
class PoiCandidate {
  const PoiCandidate({
    required this.name,
    required this.category,
    this.distanceMeters,
    this.sourceId,
  });

  final String name;
  final String category; // 'park', 'cafe', 'restaurant', 'train_station', etc.
  final int? distanceMeters;
  final String? sourceId; // Google Places place_id

  @override
  String toString() =>
      'PoiCandidate(name: $name, category: $category, distanceMeters: $distanceMeters)';
}
