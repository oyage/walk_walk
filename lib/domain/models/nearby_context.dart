import 'poi_candidate.dart';

/// 周辺情報コンテキスト
class NearbyContext {
  const NearbyContext({
    this.areaName,
    required this.landmarks,
    required this.shops,
  });

  final String? areaName; // 地域名
  final List<PoiCandidate> landmarks; // ランドマーク（最大3件）
  final List<PoiCandidate> shops; // 店舗（最大3件）

  bool get hasLandmarks => landmarks.isNotEmpty;
  bool get hasShops => shops.isNotEmpty;

  @override
  String toString() =>
      'NearbyContext(areaName: $areaName, landmarks: ${landmarks.length}, shops: ${shops.length})';
}
