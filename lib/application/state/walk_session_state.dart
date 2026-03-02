import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
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
    this.isStarting = false,
    this.countdownSeconds,
  });

  final bool isRunning;
  final String? error;
  final GuidanceMessage? lastGuidanceMessage;
  final bool isStarting;
  final int? countdownSeconds;

  WalkSessionState copyWith({
    bool? isRunning,
    String? error,
    GuidanceMessage? lastGuidanceMessage,
    bool? isStarting,
    int? countdownSeconds,
    bool clearCountdown = false,
  }) {
    return WalkSessionState(
      isRunning: isRunning ?? this.isRunning,
      error: error,
      lastGuidanceMessage: lastGuidanceMessage ?? this.lastGuidanceMessage,
      isStarting: isStarting ?? this.isStarting,
      countdownSeconds: clearCountdown
          ? null
          : (countdownSeconds ?? this.countdownSeconds),
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

/// アプリ設定（UIでの表示切替などに使用）。保存後に invalidate すると再読み込みされる。
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.read(settingsRepositoryProvider).load();
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
  Timer? _countdownTimer;
  int? _countdownIntervalSeconds;
  bool _pendingStart = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  /// カウントダウン付きでお散歩を開始予約
  Future<void> scheduleStartWithCountdown(int delaySeconds) async {
    if (state.isRunning) return;

    if (delaySeconds <= 0) {
      await start();
      return;
    }

    // 既にカウントダウン中のときは二重開始を避ける
    if (state.isStarting) return;

    _countdownIntervalSeconds = delaySeconds;
    _pendingStart = true;

    _countdownTimer?.cancel();
    state = state.copyWith(
      isStarting: true,
      countdownSeconds: delaySeconds,
      error: null,
      clearCountdown: false,
    );

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final interval = _countdownIntervalSeconds ?? delaySeconds;
      final current = state.countdownSeconds ?? interval;
      final next = current - 1;

      if (next > 0) {
        state = state.copyWith(countdownSeconds: next);
        return;
      }

      // 0 秒到達時の処理
      if (_pendingStart) {
        _pendingStart = false;
        await start();

        // start() が失敗した場合は isRunning が true にならない想定なので、その場合はカウントダウンも終了
        if (!state.isRunning) {
          timer.cancel();
          _countdownTimer = null;
          state = state.copyWith(
            isStarting: false,
            clearCountdown: true,
          );
          return;
        }

        // 正常に開始できた場合は、開始待ちフラグを下ろしつつ次の周期までのカウントダウンをセット
        state = state.copyWith(
          isStarting: false,
          countdownSeconds: interval,
          clearCountdown: false,
        );
      } else {
        // お散歩中の「次の取得まで」のカウントダウンを繰り返す
        state = state.copyWith(
          countdownSeconds: interval,
        );
      }
    });
  }

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
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _pendingStart = false;
      _countdownIntervalSeconds = null;
      state = state.copyWith(
        isStarting: false,
        clearCountdown: true,
      );
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
