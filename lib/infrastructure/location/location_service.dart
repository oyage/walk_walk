import 'package:geolocator/geolocator.dart';
import '../../domain/models/location_sample.dart';
import '../../domain/models/geo_point.dart';

/// 位置情報の権限状態
enum LocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
}

/// 位置情報サービス
class LocationService {
  /// 現在地を1回取得
  Future<LocationSample> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LocationSample(
      point: GeoPoint(
        lat: position.latitude,
        lng: position.longitude,
      ),
      timestamp: position.timestamp ?? DateTime.now(),
      accuracy: position.accuracy,
      altitude: position.altitude,
    );
  }

  /// 位置情報ストリーム（バックグラウンド用）
  Stream<LocationSample> getLocationStream({
    int intervalSeconds = 30,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 10, // 10メートル移動したら更新
        timeLimit: Duration(seconds: intervalSeconds),
      ),
    ).map((position) => LocationSample(
          point: GeoPoint(
            lat: position.latitude,
            lng: position.longitude,
          ),
          timestamp: position.timestamp ?? DateTime.now(),
          accuracy: position.accuracy,
          altitude: position.altitude,
        ));
  }

  /// 権限状態を取得
  Future<LocationPermissionStatus> getPermissionStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.denied;
    }

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  /// 権限をリクエスト
  Future<LocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('位置情報サービスが無効です');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionStatus.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }

    // バックグラウンド用にalways権限をリクエスト
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      default:
        return LocationPermissionStatus.denied;
    }
  }
}
