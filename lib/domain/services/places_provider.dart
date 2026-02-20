import '../models/geo_point.dart';
import '../models/poi_candidate.dart';

/// POI検索プロバイダーのインターフェース
abstract class PlacesProvider {
  /// 周辺のPOIを検索
  Future<List<PoiCandidate>> searchNearby({
    required GeoPoint point,
    required int radiusMeters,
    List<String>? categories,
  });
}
