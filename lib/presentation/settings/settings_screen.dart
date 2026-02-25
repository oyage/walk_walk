import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/app_settings.dart';
import '../../infrastructure/location/location_service.dart';
import '../../infrastructure/storage/settings_repository.dart';
import '../../application/state/walk_session_state.dart';

/// 設定画面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late AppSettings _settings;
  bool _isLoading = true;
  final TextEditingController _testLatController = TextEditingController();
  final TextEditingController _testLngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _testLatController.dispose();
    _testLngController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final repository = SettingsRepository();
    var settings = await repository.load();
    // 位置情報取得間隔 10-30分、検索半径 100-2000m、デバッグ間隔 5-60秒 に正規化（旧設定の互換）
    settings = settings.copyWith(
      locationUpdateIntervalSeconds:
          settings.locationUpdateIntervalSeconds.clamp(600, 1800),
      searchRadiusMeters: settings.searchRadiusMeters.clamp(100, 2000),
      debugIntervalSeconds: settings.debugIntervalSeconds.clamp(5, 60),
    );
    final prefs = await SharedPreferences.getInstance();
    final testLat = prefs.getDouble(LocationService.testLocationLatKey);
    final testLng = prefs.getDouble(LocationService.testLocationLngKey);
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
    _testLatController.text = testLat?.toString() ?? '';
    _testLngController.text = testLng?.toString() ?? '';
  }

  Future<void> _saveSettings() async {
    final repository = SettingsRepository();
    await repository.save(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  Future<void> _applyTestLocation() async {
    final lat = double.tryParse(_testLatController.text.trim());
    final lng = double.tryParse(_testLngController.text.trim());
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('緯度・経度を正しい数値で入力してください')),
        );
      }
      return;
    }
    if (lat < -90 || lat > 90) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('緯度は -90 〜 90 の範囲で入力してください')),
        );
      }
      return;
    }
    if (lng < -180 || lng > 180) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('経度は -180 〜 180 の範囲で入力してください')),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(LocationService.testLocationLatKey, lat);
    await prefs.setDouble(LocationService.testLocationLngKey, lng);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テスト位置を適用しました')),
      );
    }
  }

  Future<void> _clearTestLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LocationService.testLocationLatKey);
    await prefs.remove(LocationService.testLocationLngKey);
    _testLatController.clear();
    _testLngController.clear();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テスト位置をクリアしました')),
      );
    }
  }

  Future<void> _clearCache() async {
    final cache = ref.read(cacheRepositoryProvider);
    final historyRepo = ref.read(guidanceHistoryRepositoryProvider);
    await cache.clearAllCache();
    await historyRepo.deleteAllMessages();
    ref.read(guidanceThrottleProvider).reset();
    ref.invalidate(guidanceHistoryProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'キャッシュと案内履歴を削除しました。お散歩を停止してから再開するか、次回の案内でAPIが呼ばれます。',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '保存',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('位置情報'),
          _buildSliderSetting(
            '位置情報取得間隔（分）',
            (_settings.locationUpdateIntervalSeconds / 60.0).clamp(10.0, 30.0),
            10,
            30,
            (value) {
              setState(() {
                _settings = _settings.copyWith(
                  locationUpdateIntervalSeconds: (value.round() * 60),
                );
              });
            },
            '${(_settings.locationUpdateIntervalSeconds ~/ 60).clamp(10, 30)}分',
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            '検索半径（メートル）',
            _settings.searchRadiusMeters.toDouble().clamp(100.0, 2000.0),
            100,
            2000,
            (value) {
              setState(() {
                _settings = _settings.copyWith(
                  searchRadiusMeters: value.round(),
                );
              });
            },
            '${_settings.searchRadiusMeters.clamp(100, 2000)}m',
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('テスト用位置（DEV）'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'DEV時のみ。指定するとこの座標が現在地として使われます。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            TextFormField(
              controller: _testLatController,
              decoration: const InputDecoration(
                labelText: '緯度',
                hintText: '例: 35.6812',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _testLngController,
              decoration: const InputDecoration(
                labelText: '経度',
                hintText: '例: 139.7671',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _applyTestLocation,
                  child: const Text('適用'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearTestLocation,
                  child: const Text('クリア'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('デバッグ用短縮間隔（DEV）'),
            SwitchListTile(
              title: const Text('デバッグ用短縮間隔を使用'),
              subtitle: Text(
                'ON: ${_settings.debugIntervalSeconds}秒間隔で位置取得・案内',
                style: const TextStyle(fontSize: 12),
              ),
              value: _settings.useDebugInterval,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(useDebugInterval: value);
                });
              },
            ),
            if (_settings.useDebugInterval) ...[
              _buildSliderSetting(
                '取得間隔（秒）',
                _settings.debugIntervalSeconds.toDouble().clamp(5.0, 60.0),
                5,
                60,
                (value) {
                  setState(() {
                    _settings = _settings.copyWith(
                      debugIntervalSeconds: value.round(),
                    );
                  });
                },
                '${_settings.debugIntervalSeconds.clamp(5, 60)}秒',
                divisions: 55,
              ),
            ],
            const SizedBox(height: 16),
          ],
          const Divider(height: 32),
          _buildSectionTitle('案内設定'),
          _buildSliderSetting(
            '案内クールダウン（秒）',
            _settings.cooldownSeconds.toDouble(),
            10,
            120,
            (value) {
              setState(() {
                _settings = _settings.copyWith(
                  cooldownSeconds: value.round(),
                );
              });
            },
            '${_settings.cooldownSeconds}秒',
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            '距離閾値（メートル）',
            _settings.distanceThresholdMeters.toDouble(),
            10,
            100,
            (value) {
              setState(() {
                _settings = _settings.copyWith(
                  distanceThresholdMeters: value.round(),
                );
              });
            },
            '${_settings.distanceThresholdMeters}m',
          ),
          const Divider(height: 32),
          _buildSectionTitle('音声設定'),
          _buildSliderSetting(
            'TTS速度',
            _settings.ttsSpeechRate,
            0.0,
            1.0,
            (value) {
              setState(() {
                _settings = _settings.copyWith(
                  ttsSpeechRate: value,
                );
              });
            },
            _settings.ttsSpeechRate.toStringAsFixed(2),
          ),
          const SizedBox(height: 16),
          _buildDropdownSetting(
            'TTS言語',
            _settings.ttsLanguage,
            ['ja', 'en'],
            (value) {
              setState(() {
                _settings = _settings.copyWith(ttsLanguage: value!);
              });
            },
          ),
          const SizedBox(height: 16),
          if (defaultTargetPlatform == TargetPlatform.android)
            SwitchListTile(
              title: const Text('アプリ内合成音声を使用（ベータ）'),
              subtitle: const Text(
                'OSのTTSではなく、アプリに組み込んだ合成音声エンジンで再生します（現在はAndroidのみ対応）。',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.useEmbeddedTts,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(useEmbeddedTts: value);
                });
              },
            ),
          const Divider(height: 32),
          _buildSectionTitle('その他'),
          _buildSliderSetting(
            '履歴保持期間（時間）',
            _settings.historyRetentionHours.toDouble(),
            24,
            720,
            (value) {
              setState(() {
                _settings = _settings.copyWith(
                  historyRetentionHours: value.round(),
                );
              });
            },
            '${_settings.historyRetentionHours}時間',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('バックグラウンド動作'),
            subtitle: const Text('アプリを閉じても案内を続けます'),
            value: _settings.enableBackgroundMode,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(enableBackgroundMode: value);
              });
            },
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'DEV: ジオ・POIキャッシュと案内履歴を削除します。次回案内でAPIが呼ばれログが出ます。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('キャッシュ・案内履歴を削除'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Slider の divisions。0 以下にならないようにする（Flutter のアサーション対応）
  int? _sliderDivisions(double min, double max) {
    if (max <= min) return null;
    final n = ((max - min) / 10).round();
    return n > 0 ? n : 1;
  }

  Widget _buildSliderSetting(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String valueLabel, {
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? _sliderDivisions(min, max),
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdownSetting<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString().toUpperCase()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
