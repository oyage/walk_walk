import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/location_sample.dart';
import '../../infrastructure/location/location_service.dart';
import '../utils/network_error_util.dart';

/// 位置情報サービスのプロバイダ
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// 現在地の状態
class CurrentLocationState {
  const CurrentLocationState({
    this.location,
    this.isLoading = false,
    this.error,
  });

  final LocationSample? location;
  final bool isLoading;
  final String? error;

  CurrentLocationState copyWith({
    LocationSample? location,
    bool? isLoading,
    String? error,
  }) {
    return CurrentLocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 現在地の状態プロバイダ
final currentLocationProvider =
    StateNotifierProvider<CurrentLocationNotifier, CurrentLocationState>(
  (ref) {
    return CurrentLocationNotifier(ref.read(locationServiceProvider));
  },
);

class CurrentLocationNotifier extends StateNotifier<CurrentLocationState> {
  CurrentLocationNotifier(this._locationService)
      : super(const CurrentLocationState());

  final LocationService _locationService;

  /// 現在地を取得
  Future<void> fetchCurrentLocation() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final location = await _locationService.getCurrentLocation();
      state = state.copyWith(location: location, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: userFacingErrorMessage(e),
      );
    }
  }

  /// 権限をリクエストしてから現在地を取得（DEV用）
  Future<void> requestPermissionAndFetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _locationService.requestPermission();
      await fetchCurrentLocation();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: userFacingErrorMessage(e),
      );
    }
  }

  /// アプリ設定画面を開く（DEV用・権限が「許可しない」のとき）
  /// 開けた場合 true、開けなかった場合（未対応端末等）false
  Future<bool> openAppSettings() async {
    return await _locationService.openAppSettings();
  }
}
