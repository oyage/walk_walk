import 'package:uuid/uuid.dart';
import '../../domain/models/guidance_message.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/nearby_context.dart';
import '../../domain/models/poi_candidate.dart';
import '../../infrastructure/location/location_service.dart';
import '../../infrastructure/storage/settings_repository.dart';
import '../../infrastructure/storage/guidance_history_repository.dart';
import '../../infrastructure/tts/tts_service.dart';
import '../../domain/services/guidance_formatter.dart';
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
  final FetchNearbyInfoUseCase _fetchNearbyInfoUseCase;
  final void Function()? onGuidanceRecorded;
  BackgroundWorker? _backgroundWorker;

  bool _isRunning = false;
  bool _isPerformingGuidance = false;
  AppSettings? _currentSettings;

  WalkSessionUseCase(
    this._locationService,
    this._settingsRepository,
    this._historyRepository,
    this._ttsService,
    this._formatter,
    this._fetchNearbyInfoUseCase, {
    this.onGuidanceRecorded,
  });

  /// お散歩を開始
  Future<void> start() async {
    if (_isRunning) return;

    // 設定を読み込み
    _currentSettings = await _settingsRepository.load();

    // 権限チェック（未許可の場合は一度リクエストしてダイアログを表示）
    var permission = await _locationService.getPermissionStatus();
    if (permission != LocationPermissionStatus.whileInUse &&
        permission != LocationPermissionStatus.always) {
      permission = await _locationService.requestPermission();
      if (permission != LocationPermissionStatus.whileInUse &&
          permission != LocationPermissionStatus.always) {
        throw Exception(
          '位置情報の権限が必要です。設定アプリから「Walk Walk」の位置情報を許可してください。',
        );
      }
    }

    _isRunning = true;

    // バックグラウンドワーカーを起動
    if (_currentSettings!.enableBackgroundMode) {
      _backgroundWorker = BackgroundWorker(
        _locationService,
        this,
      );
      await _backgroundWorker!.start(_currentSettings!);
      // 初回案内は BackgroundWorker.start() 内の _performGuidance() で実行済みのためここでは呼ばない
    } else {
      // 前景のみのときは開始直後に1回案内を実行
      performGuidance();
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
    if (_isPerformingGuidance) return;

    _isPerformingGuidance = true;
    try {
      // 位置取得
      final location = await _locationService.getCurrentLocation();

      // テスト位置が設定されている場合はキャッシュをスキップし、設定した座標で実際にAPI検索を行う
      final useTestApiSearch = await _locationService.hasTestLocation();

      // 周辺情報取得
      final context = await _fetchNearbyInfoUseCase.fetchNearbyInfo(
        location.point,
        _currentSettings!.searchRadiusMeters,
        skipCache: useTestApiSearch,
      );

      // 履歴から直近で案内した施設名を取得（同一施設は別のを優先するため）
      final recentMessages =
          await _historyRepository.getRecentMessages(limit: 20);
      final recentNames = <String>{};
      for (final msg in recentMessages) {
        for (final p in msg.guidedPlaces) {
          final n = p.name.trim().toLowerCase();
          if (n.isNotEmpty) recentNames.add(n);
        }
      }

      // 履歴にない施設を優先して最大3件ずつ選ぶ。同一のみの場合はそのまま案内
      const int maxPerCategory = 3;
      final selectedLandmarks = _selectPrioritizingNotInHistory(
        context.landmarks,
        recentNames,
        maxPerCategory,
      );
      final selectedShops = _selectPrioritizingNotInHistory(
        context.shops,
        recentNames,
        maxPerCategory,
      );
      final filteredContext = NearbyContext(
        areaName: context.areaName,
        landmarks: selectedLandmarks,
        shops: selectedShops,
      );

      // 文章生成
      final text = _formatter.format(filteredContext, _currentSettings!);

      // 読み上げ
      await _ttsService.speak(text, _currentSettings!);

      // 案内した施設の名前とマップURL（選定した POI から生成）
      final pois = [...selectedLandmarks, ...selectedShops];
      final guidedPlaces = [
        for (final p in pois)
          if (p.sourceId != null && p.sourceId!.isNotEmpty)
            GuidedPlace(
              name: p.name,
              url: 'https://www.google.com/maps/place/?q=place_id:${p.sourceId}',
            ),
      ];

      // 履歴保存（施設名・マップURLリストを残す）
      final message = GuidanceMessage(
        id: const Uuid().v4(),
        guidedPlaces: guidedPlaces,
        createdAt: DateTime.now(),
        point: location.point,
        areaName: filteredContext.areaName,
        tags: [
          if (filteredContext.hasLandmarks) 'landmark',
          if (filteredContext.hasShops) 'shop',
        ],
      );
      await _historyRepository.addMessage(message);
      onGuidanceRecorded?.call();
    } catch (e, stackTrace) {
      // エラーはログに記録
      AppLogger.e('案内実行中にエラーが発生しました', e, stackTrace);
      rethrow; // 呼び出し元でエラーを処理できるように再スロー
    } finally {
      _isPerformingGuidance = false;
    }
  }

  bool get isRunning => _isRunning;

  /// 履歴にない施設を優先して最大 [maxCount] 件を選ぶ。同一のみの場合はそのまま返す。
  static List<PoiCandidate> _selectPrioritizingNotInHistory(
    List<PoiCandidate> candidates,
    Set<String> recentNames,
    int maxCount,
  ) {
    final notInHistory = <PoiCandidate>[];
    final inHistory = <PoiCandidate>[];
    for (final p in candidates) {
      final key = p.name.trim().toLowerCase();
      if (key.isEmpty || recentNames.contains(key)) {
        inHistory.add(p);
      } else {
        notInHistory.add(p);
      }
    }
    return [...notInHistory.take(maxCount), ...inHistory]
        .take(maxCount)
        .toList();
  }
}
