import 'geo_point.dart';

/// 案内した施設（名前と地図URL）
class GuidedPlace {
  const GuidedPlace({required this.name, required this.url});
  final String name;
  final String url;
}

/// 案内メッセージ（案内した建物の名前・マップURLリストを保持）
class GuidanceMessage {
  const GuidanceMessage({
    required this.id,
    required this.guidedPlaces,
    required this.createdAt,
    required this.point,
    this.areaName,
    required this.tags,
  });

  final String id;
  /// 案内した施設の名前と Google マップ URL のリスト
  final List<GuidedPlace> guidedPlaces;
  final DateTime createdAt;
  final GeoPoint point;
  final String? areaName;
  final List<String> tags; // ['landmark', 'shop']

  @override
  String toString() =>
      'GuidanceMessage(id: $id, guidedPlaces: ${guidedPlaces.length}件, createdAt: $createdAt, tags: $tags)';
}
