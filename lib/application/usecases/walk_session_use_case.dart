import 'package:uuid/uuid.dart';
import '../../domain/models/geo_point.dart';
import '../../domain/models/guidance_message.dart';
import '../../domain/models/app_settings.dart';
import '../../infrastructure/location/location_service.dart';
import '../../infrastructure/storage/settings_repository.dart';
import '../../infrastructure/storage/guidance_history_repository.dart';
import '../../infrastructure/tts/tts_service.dart';
import '../../domain/services/guidance_formatter.dart';
import '../../domain/services/guidance_throttle.dart';
import '../../infrastructure/background/background_worker.dart';
import '../../infrastructure/logging/app_logger.dart';
import 'fetch_nearby_info_use_case.dart';

/// お散歩セッション管理ユースケース
class WalkSessionUseCase {
  final LocationService _locationService;
  final SettingsRepository _settingsRepository;
  final GuidanceHistoryRepository _historyRepository;
  final TtsService _ttsService;
  final GuidanceFormatter _formatter;
  final GuidanceThrottle _throttle;
  final FetchNearbyInfoUseCase _fetchNearbyInfoUseCase;
  BackgroundWorker? _backgroundWorker;

  bool _isRunning = false;
  AppSettings? _currentSettings;

  WalkSessionUseCase(
    this._locationService,
    this._settingsRepository,
    this._historyRepository,
    this._ttsService,
    this._formatter,
    this._throttle,
    this._fetchNearbyInfoUseCase,
  );

  /// お散歩を開始
  Future<void> start() async {
    if (_isRunning) return;

    // 設定を読み込み
    _currentSettings = await _settingsRepository.load();

    // 権限チェック
    final permission = await _locationService.getPermissionStatus();
    if (permission != LocationPermissionStatus.whileInUse &&
        permission != LocationPermissionStatus.always) {
      throw Exception('位置情報の権限が必要です');
    }

    _isRunning = true;

    // バックグラウンドワーカーを起動
    if (_currentSettings!.enableBackgroundMode) {
      _backgroundWorker = BackgroundWorker(
        _locationService,
        this,
        _fetchNearbyInfoUseCase,
      );
      await _backgroundWorker!.start(_currentSettings!);
    }
  }

  /// お散歩を停止
  Future<void> stop() async {
    _isRunning = false;
    await _ttsService.stop();

    // バックグラウンドワーカーを停止
    if (_backgroundWorker != null) {
      await _backgroundWorker!.stop();
      _backgroundWorker = null;
    }
  }

  /// 1回の案内を実行（前景用）
  Future<void> performGuidance() async {
    if (!_isRunning || _currentSettings == null) return;

    try {
      // 位置取得
      final location = await _locationService.getCurrentLocation();

      // 周辺情報取得
      final context = await _fetchNearbyInfoUseCase.fetchNearbyInfo(
        location.point,
        _currentSettings!.searchRadiusMeters,
      );

      // 抑制判定
      final poiNames = [
        ...context.landmarks.map((l) => l.name),
        ...context.shops.map((s) => s.name),
      ];
      if (!_throttle.shouldSpeak(
        location.point,
        _currentSettings!,
        poiNames,
      )) {
        return; // 案内をスキップ
      }

      // 文章生成
      final text = _formatter.format(context, _currentSettings!);

      // 読み上げ
      await _ttsService.speak(text, _currentSettings!);

      // 履歴保存
      final message = GuidanceMessage(
        id: const Uuid().v4(),
        text: text,
        createdAt: DateTime.now(),
        point: location.point,
        areaName: context.areaName,
        tags: [
          if (context.hasLandmarks) 'landmark',
          if (context.hasShops) 'shop',
        ],
      );
      await _historyRepository.addMessage(message);
    } catch (e, stackTrace) {
      // エラーはログに記録
      AppLogger.e('案内実行中にエラーが発生しました', e, stackTrace);
      rethrow; // 呼び出し元でエラーを処理できるように再スロー
    }
  }

  bool get isRunning => _isRunning;
}
