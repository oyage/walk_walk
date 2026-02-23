import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  /// テスト用位置の保存キー（DEV時のみ設定画面で使用）
  static const String testLocationLatKey = 'walk_walk_test_lat';
  static const String testLocationLngKey = 'walk_walk_test_lng';

  /// テスト用位置が設定されているか（DEV時・設定画面やAPI検索の挙動判定に使用）
  Future<bool> hasTestLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(testLocationLatKey);
    final lng = prefs.getDouble(testLocationLngKey);
    return lat != null && lng != null;
  }

  /// 現在地を1回取得（テスト用位置が保存されていればそれを返す）
  Future<LocationSample> getCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(testLocationLatKey);
    final lng = prefs.getDouble(testLocationLngKey);
    if (lat != null && lng != null) {
      return LocationSample(
        point: GeoPoint(lat: lat, lng: lng),
        timestamp: DateTime.now(),
        accuracy: null,
        altitude: null,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LocationSample(
      point: GeoPoint(
        lat: position.latitude,
        lng: position.longitude,
      ),
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      );
    } on Exception catch (_) {
      throw Exception(
        '位置情報はこの端末では利用できません。'
        'スマートフォンまたは実機でお試しください。',
      );
    }
  }

  /// 位置情報ストリーム（バックグラウンド用）。テスト用位置が保存されていればそれを定期発火
  Stream<LocationSample> getLocationStream({
    int intervalSeconds = 30,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async* {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(testLocationLatKey);
    final lng = prefs.getDouble(testLocationLngKey);
    if (lat != null && lng != null) {
      yield* Stream.periodic(
        Duration(seconds: intervalSeconds),
        (_) => LocationSample(
          point: GeoPoint(lat: lat, lng: lng),
          timestamp: DateTime.now(),
          accuracy: null,
          altitude: null,
        ),
      );
      return;
    }

    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 10,
        timeLimit: Duration(seconds: intervalSeconds),
      ),
    ).map((position) => LocationSample(
          point: GeoPoint(
            lat: position.latitude,
            lng: position.longitude,
          ),
          timestamp: position.timestamp,
          accuracy: position.accuracy,
          altitude: position.altitude,
        ));
  }

  /// 権限状態を取得
  Future<LocationPermissionStatus> getPermissionStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.denied;
      }
    } on Exception catch (_) {
      return LocationPermissionStatus.denied;
    }

    try {
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
    } on Exception catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  /// 権限をリクエスト
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('位置情報サービスが無効です');
      }
    } on Exception catch (_) {
      return LocationPermissionStatus.denied;
    }

    try {
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
    } on Exception catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  /// アプリの設定画面を開く（権限が「許可しない」のときに手動で許可する用）
  /// Android/iOS では app_settings で位置情報設定を開く。未対応端末では false を返す
  Future<bool> openAppSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.location);
      return true;
    } catch (_) {
      // app_settings が使えない場合（Linux等）は geolocator を試す
    }
    try {
      return await Geolocator.openAppSettings();
    } on MissingPluginException catch (_) {
      return false;
    } on UnimplementedError catch (_) {
      return false;
    }
  }

  /// 端末の位置情報設定画面を開く
  /// Linux 等で未実装の場合は false を返す
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } on MissingPluginException catch (_) {
      return false;
    } on UnimplementedError catch (_) {
      return false;
    }
  }
}
