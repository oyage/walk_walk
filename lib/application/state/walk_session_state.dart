import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/guidance_message.dart';
import '../../infrastructure/storage/database.dart' hide GuidanceMessage;
import '../../infrastructure/storage/guidance_history_repository.dart';
import '../../infrastructure/storage/settings_repository.dart';
import '../../infrastructure/location/location_service.dart';
import '../../infrastructure/tts/tts_service.dart';
import '../../infrastructure/external/geocoding/google_geocoding_provider.dart';
import '../../infrastructure/external/places/google_places_provider.dart';
import '../../infrastructure/formatters/guidance_formatter_impl.dart';
import '../../infrastructure/storage/cache_repository.dart';
import '../usecases/walk_session_use_case.dart';
import '../usecases/fetch_nearby_info_use_case.dart';
import '../utils/network_error_util.dart';

/// お散歩セッションの状態
class WalkSessionState {
  const WalkSessionState({
    this.isRunning = false,
    this.error,
    this.lastGuidanceMessage,
  });

  final bool isRunning;
  final String? error;
  final GuidanceMessage? lastGuidanceMessage;

  WalkSessionState copyWith({
    bool? isRunning,
    String? error,
    GuidanceMessage? lastGuidanceMessage,
  }) {
    return WalkSessionState(
      isRunning: isRunning ?? this.isRunning,
      error: error,
      lastGuidanceMessage: lastGuidanceMessage ?? this.lastGuidanceMessage,
    );
  }
}

/// データベースプロバイダー
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// リポジトリ・サービスのプロバイダー
final cacheRepositoryProvider = Provider<CacheRepository>((ref) {
  return CacheRepository(ref.read(databaseProvider));
});

final guidanceHistoryRepositoryProvider =
    Provider<GuidanceHistoryRepository>((ref) {
  return GuidanceHistoryRepository(ref.read(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

final geocodingProvider = Provider<GoogleGeocodingProvider>((ref) {
  return GoogleGeocodingProvider();
});

final placesProvider = Provider<GooglePlacesProvider>((ref) {
  return GooglePlacesProvider();
});

final guidanceFormatterProvider = Provider<GuidanceFormatterImpl>((ref) {
  return GuidanceFormatterImpl();
});

final fetchNearbyInfoUseCaseProvider =
    Provider<FetchNearbyInfoUseCase>((ref) {
  return FetchNearbyInfoUseCase(
    ref.read(geocodingProvider),
    ref.read(placesProvider),
    ref.read(cacheRepositoryProvider),
  );
});

final walkSessionUseCaseProvider = Provider<WalkSessionUseCase>((ref) {
  return WalkSessionUseCase(
    ref.read(locationServiceProvider),
    ref.read(settingsRepositoryProvider),
    ref.read(guidanceHistoryRepositoryProvider),
    ref.read(ttsServiceProvider),
    ref.read(guidanceFormatterProvider),
    ref.read(fetchNearbyInfoUseCaseProvider),
    onGuidanceRecorded: () => ref.invalidate(guidanceHistoryProvider),
  );
});

/// お散歩セッションの状態プロバイダー
final walkSessionStateProvider =
    StateNotifierProvider<WalkSessionNotifier, WalkSessionState>((ref) {
  return WalkSessionNotifier(ref.read(walkSessionUseCaseProvider));
});

class WalkSessionNotifier extends StateNotifier<WalkSessionState> {
  WalkSessionNotifier(this._useCase) : super(const WalkSessionState());

  final WalkSessionUseCase _useCase;

  /// お散歩を開始
  Future<void> start() async {
    try {
      await _useCase.start();
      state = state.copyWith(isRunning: true, error: null);
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: userFacingErrorMessage(e),
      );
    }
  }

  /// お散歩を停止
  Future<void> stop() async {
    try {
      await _useCase.stop();
      state = state.copyWith(isRunning: false, error: null);
    } catch (e) {
      state = state.copyWith(error: userFacingErrorMessage(e));
    }
  }

  /// 案内を実行
  Future<void> performGuidance() async {
    if (!state.isRunning) return;

    try {
      await _useCase.performGuidance();
      // 最新の案内メッセージを取得して状態を更新
      // TODO: WalkSessionUseCaseから最新メッセージを取得する方法を追加
    } catch (e) {
      state = state.copyWith(error: userFacingErrorMessage(e));
    }
  }
}

/// 案内履歴プロバイダー
final guidanceHistoryProvider =
    FutureProvider<List<GuidanceMessage>>((ref) async {
  final repository = ref.read(guidanceHistoryRepositoryProvider);
  return await repository.getRecentMessages(limit: 50);
});
