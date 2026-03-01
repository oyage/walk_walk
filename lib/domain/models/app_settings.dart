/// アプリ設定
class AppSettings {
  const AppSettings({
    this.locationUpdateIntervalSeconds = 900, // 15分
    this.searchRadiusMeters = 500,
    this.historyRetentionHours = 168, // 7日間
    this.ttsSpeechRate = 0.5,
    this.ttsLanguage = 'ja',
    this.enableBackgroundMode = true,
    this.useDebugInterval = false,
    this.debugIntervalSeconds = 30,
    this.useEmbeddedTts = false,
    this.showDevUi = true,
  });

  final int locationUpdateIntervalSeconds; // 位置情報取得間隔（10-30分＝600-1800秒）
  final int searchRadiusMeters; // 検索半径（100-2000メートル）
  final int historyRetentionHours; // 履歴保持期間（24-720時間）
  final double ttsSpeechRate; // TTS速度（0.0-1.0）
  final String ttsLanguage; // 'ja', 'en', etc.
  final bool enableBackgroundMode; // バックグラウンド動作有効化
  /// DEV用: 短い取得間隔を使うか
  final bool useDebugInterval;
  /// DEV用: 短縮間隔の秒数（5-60）
  final int debugIntervalSeconds;
  /// アプリ内組み込みTTSを使用するか（現在はAndroidなど対応プラットフォームのみ有効）
  final bool useEmbeddedTts;
  /// DEV時のみ: true=DEV用UI表示, false=Pub風表示
  final bool showDevUi;

  /// 実際に使う位置取得間隔（秒）。useDebugInterval が true なら debugIntervalSeconds、そうでなければ locationUpdateIntervalSeconds
  int get effectiveIntervalSeconds =>
      useDebugInterval ? debugIntervalSeconds : locationUpdateIntervalSeconds;

  AppSettings copyWith({
    int? locationUpdateIntervalSeconds,
    int? searchRadiusMeters,
    int? historyRetentionHours,
    double? ttsSpeechRate,
    String? ttsLanguage,
    bool? enableBackgroundMode,
    bool? useDebugInterval,
    int? debugIntervalSeconds,
    bool? useEmbeddedTts,
    bool? showDevUi,
  }) {
    return AppSettings(
      locationUpdateIntervalSeconds:
          locationUpdateIntervalSeconds ?? this.locationUpdateIntervalSeconds,
      searchRadiusMeters: searchRadiusMeters ?? this.searchRadiusMeters,
      historyRetentionHours:
          historyRetentionHours ?? this.historyRetentionHours,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      enableBackgroundMode:
          enableBackgroundMode ?? this.enableBackgroundMode,
      useDebugInterval: useDebugInterval ?? this.useDebugInterval,
      debugIntervalSeconds:
          debugIntervalSeconds ?? this.debugIntervalSeconds,
      useEmbeddedTts: useEmbeddedTts ?? this.useEmbeddedTts,
      showDevUi: showDevUi ?? this.showDevUi,
    );
  }

  Map<String, dynamic> toJson() => {
        'locationUpdateIntervalSeconds': locationUpdateIntervalSeconds,
        'searchRadiusMeters': searchRadiusMeters,
        'historyRetentionHours': historyRetentionHours,
        'ttsSpeechRate': ttsSpeechRate,
        'ttsLanguage': ttsLanguage,
        'enableBackgroundMode': enableBackgroundMode,
        'useDebugInterval': useDebugInterval,
        'debugIntervalSeconds': debugIntervalSeconds,
        'useEmbeddedTts': useEmbeddedTts,
        'showDevUi': showDevUi,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        locationUpdateIntervalSeconds:
            json['locationUpdateIntervalSeconds'] as int? ?? 900,
        searchRadiusMeters: json['searchRadiusMeters'] as int? ?? 500,
        historyRetentionHours: json['historyRetentionHours'] as int? ?? 168,
        ttsSpeechRate: (json['ttsSpeechRate'] as num?)?.toDouble() ?? 0.5,
        ttsLanguage: json['ttsLanguage'] as String? ?? 'ja',
        enableBackgroundMode:
            json['enableBackgroundMode'] as bool? ?? true,
        useDebugInterval: json['useDebugInterval'] as bool? ?? false,
        debugIntervalSeconds:
            json['debugIntervalSeconds'] as int? ?? 30,
        useEmbeddedTts: json['useEmbeddedTts'] as bool? ?? false,
        showDevUi: json['showDevUi'] as bool? ?? true,
      );

  @override
  String toString() =>
      'AppSettings(locationUpdateIntervalSeconds: $locationUpdateIntervalSeconds, '
      'searchRadiusMeters: $searchRadiusMeters)';
}
