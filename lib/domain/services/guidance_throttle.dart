import 'dart:math' as math;
import '../models/geo_point.dart';
import '../models/app_settings.dart';

/// 案内の抑制ロジック（クールダウン・距離閾値・重複抑制）
class GuidanceThrottle {
  DateTime? _lastGuidanceAt;
  GeoPoint? _lastGuidancePoint;
  final List<String> _recentPoiNames = [];

  /// 案内すべきかどうかを判定
  bool shouldSpeak(
    GeoPoint currentPoint,
    AppSettings settings,
    List<String> currentPoiNames,
  ) {
    final now = DateTime.now();

    // クールダウンチェック
    if (_lastGuidanceAt != null) {
      final elapsed = now.difference(_lastGuidanceAt!);
      if (elapsed.inSeconds < settings.cooldownSeconds) {
        return false;
      }
    }

    // 距離閾値チェック
    if (_lastGuidancePoint != null) {
      final distance = _calculateDistance(
        _lastGuidancePoint!.lat,
        _lastGuidancePoint!.lng,
        currentPoint.lat,
        currentPoint.lng,
      );
      if (distance < settings.distanceThresholdMeters) {
        return false;
      }
    }

    // 重複抑制チェック（簡易版）
    if (_recentPoiNames.isNotEmpty) {
      final hasNewPoi = currentPoiNames.any(
        (name) => !_recentPoiNames.contains(name),
      );
      if (!hasNewPoi && _recentPoiNames.length >= 3) {
        return false; // 同じPOIばかり案内しない
      }
    }

    // 案内可能
    _lastGuidanceAt = now;
    _lastGuidancePoint = currentPoint;
    _recentPoiNames.clear();
    _recentPoiNames.addAll(currentPoiNames.take(5)); // 直近5件を保持

    return true;
  }

  /// 2点間の距離を計算（メートル）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);
}
