import 'geo_point.dart';

/// 案内メッセージ（案内した建物のマップURLリストを保持）
class GuidanceMessage {
  const GuidanceMessage({
    required this.id,
    required this.mapUrls,
    required this.createdAt,
    required this.point,
    this.areaName,
    required this.tags,
  });

  final String id;
  /// 案内した建物の Google マップ URL リスト（place_id ベース）
  final List<String> mapUrls;
  final DateTime createdAt;
  final GeoPoint point;
  final String? areaName;
  final List<String> tags; // ['landmark', 'shop']

  @override
  String toString() =>
      'GuidanceMessage(id: $id, mapUrls: ${mapUrls.length}件, createdAt: $createdAt, tags: $tags)';
}
