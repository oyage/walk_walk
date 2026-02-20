import '../models/geo_point.dart';

/// 逆ジオコーディングプロバイダーのインターフェース
abstract class GeocodingProvider {
  /// 座標から地域名を取得
  Future<String?> reverseGeocode(GeoPoint point);
}
