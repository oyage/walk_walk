import 'geo_point.dart';

/// 位置情報サンプル
class LocationSample {
  const LocationSample({
    required this.point,
    required this.timestamp,
    this.accuracy,
    this.altitude,
  });

  final GeoPoint point;
  final DateTime timestamp;
  final double? accuracy; // メートル
  final double? altitude; // メートル

  @override
  String toString() =>
      'LocationSample(point: $point, timestamp: $timestamp, accuracy: $accuracy, altitude: $altitude)';
}
