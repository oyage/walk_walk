/// アプリ設定
class AppSettings {
  const AppSettings({
    this.locationUpdateIntervalSeconds = 900, // 15分
    this.searchRadiusMeters = 500,
    this.cooldownSeconds = 30,
    this.distanceThresholdMeters = 50,
    this.historyRetentionHours = 168, // 7日間
    this.ttsSpeechRate = 0.5,
    this.ttsLanguage = 'ja',
    this.enableBackgroundMode = true,
  });

  final int locationUpdateIntervalSeconds; // 位置情報取得間隔（10-30分＝600-1800秒）
  final int searchRadiusMeters; // 検索半径（100-2000メートル）
  final int cooldownSeconds; // 案内クールダウン（10-120秒）
  final int distanceThresholdMeters; // 距離閾値（10-100メートル）
  final int historyRetentionHours; // 履歴保持期間（24-720時間）
  final double ttsSpeechRate; // TTS速度（0.0-1.0）
  final String ttsLanguage; // 'ja', 'en', etc.
  final bool enableBackgroundMode; // バックグラウンド動作有効化

  AppSettings copyWith({
    int? locationUpdateIntervalSeconds,
    int? searchRadiusMeters,
    int? cooldownSeconds,
    int? distanceThresholdMeters,
    int? historyRetentionHours,
    double? ttsSpeechRate,
    String? ttsLanguage,
    bool? enableBackgroundMode,
  }) {
    return AppSettings(
      locationUpdateIntervalSeconds:
          locationUpdateIntervalSeconds ?? this.locationUpdateIntervalSeconds,
      searchRadiusMeters: searchRadiusMeters ?? this.searchRadiusMeters,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      distanceThresholdMeters:
          distanceThresholdMeters ?? this.distanceThresholdMeters,
      historyRetentionHours:
          historyRetentionHours ?? this.historyRetentionHours,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      enableBackgroundMode:
          enableBackgroundMode ?? this.enableBackgroundMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'locationUpdateIntervalSeconds': locationUpdateIntervalSeconds,
        'searchRadiusMeters': searchRadiusMeters,
        'cooldownSeconds': cooldownSeconds,
        'distanceThresholdMeters': distanceThresholdMeters,
        'historyRetentionHours': historyRetentionHours,
        'ttsSpeechRate': ttsSpeechRate,
        'ttsLanguage': ttsLanguage,
        'enableBackgroundMode': enableBackgroundMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        locationUpdateIntervalSeconds:
            json['locationUpdateIntervalSeconds'] as int? ?? 900,
        searchRadiusMeters: json['searchRadiusMeters'] as int? ?? 500,
        cooldownSeconds: json['cooldownSeconds'] as int? ?? 30,
        distanceThresholdMeters:
            json['distanceThresholdMeters'] as int? ?? 50,
        historyRetentionHours: json['historyRetentionHours'] as int? ?? 168,
        ttsSpeechRate: (json['ttsSpeechRate'] as num?)?.toDouble() ?? 0.5,
        ttsLanguage: json['ttsLanguage'] as String? ?? 'ja',
        enableBackgroundMode:
            json['enableBackgroundMode'] as bool? ?? true,
      );

  @override
  String toString() =>
      'AppSettings(locationUpdateIntervalSeconds: $locationUpdateIntervalSeconds, '
      'searchRadiusMeters: $searchRadiusMeters, cooldownSeconds: $cooldownSeconds)';
}
