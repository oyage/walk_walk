import 'dart:async';
import '../../domain/models/app_settings.dart';
import '../location/location_service.dart';
import '../notifications/notification_service.dart';
import '../logging/app_logger.dart';
import '../../application/usecases/walk_session_use_case.dart';

/// バックグラウンドワーカー
/// 位置情報を監視し、定期的に案内を実行
class BackgroundWorker {
  bool _isRunning = false;
  StreamSubscription<dynamic>? _locationSubscription;
  Timer? _guidanceTimer;
  final LocationService _locationService;
  final WalkSessionUseCase _walkSessionUseCase;
  AppSettings? _currentSettings;

  BackgroundWorker(
    this._locationService,
    this._walkSessionUseCase,
  );

  /// バックグラウンドワーカーを開始
  Future<void> start(AppSettings settings) async {
    if (_isRunning) return;

    _currentSettings = settings;
    _isRunning = true;

    // 通知を表示（Android Foreground Service用）
    await NotificationService.showNotification(
      id: 1,
      title: 'Walk Walk',
      body: 'お散歩案内を開始しました',
    );

    // 位置情報ストリームを開始
    _locationSubscription = _locationService
        .getLocationStream(
          intervalSeconds: settings.locationUpdateIntervalSeconds,
        )
        .listen(
          (location) {
            // 位置情報が更新されたら案内を実行
            _performGuidance();
          },
          onError: (error, stackTrace) {
            // エラー処理
            AppLogger.e('位置情報ストリームエラー', error, stackTrace);
          },
        );

    // 定期的な案内タイマー（フォールバック）
    _guidanceTimer = Timer.periodic(
      Duration(seconds: settings.locationUpdateIntervalSeconds),
      (_) => _performGuidance(),
    );
  }

  /// バックグラウンドワーカーを停止
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _guidanceTimer?.cancel();
    _guidanceTimer = null;

    // 通知をキャンセル
    await NotificationService.cancelNotification(1);
  }

  /// 案内を実行
  Future<void> _performGuidance() async {
    if (!_isRunning || _currentSettings == null) return;

    try {
      await _walkSessionUseCase.performGuidance();
    } catch (e, stackTrace) {
      AppLogger.e('案内実行エラー', e, stackTrace);
      // エラー時も通知を更新
      await NotificationService.showNotification(
        id: 1,
        title: 'Walk Walk',
        body: '案内中にエラーが発生しました',
      );
    }
  }

  bool get isRunning => _isRunning;
}
