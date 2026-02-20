import 'geo_point.dart';

/// 案内メッセージ
class GuidanceMessage {
  const GuidanceMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.point,
    this.areaName,
    required this.tags,
  });

  final String id;
  final String text; // 案内テキスト
  final DateTime createdAt;
  final GeoPoint point;
  final String? areaName;
  final List<String> tags; // ['landmark', 'shop']

  @override
  String toString() =>
      'GuidanceMessage(id: $id, text: $text, createdAt: $createdAt, tags: $tags)';
}
