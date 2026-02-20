import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repository = SettingsRepository();
    var settings = await repository.load();
    // 位置情報取得間隔 10-30分、検索半径 100-2000m に正規化（旧設定の互換）
    settings = settings.copyWith(
      locationUpdateIntervalSeconds:
          settings.locationUpdateIntervalSeconds.clamp(600, 1800),
      searchRadiusMeters: settings.searchRadiusMeters.clamp(100, 2000),
    );
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
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
    String valueLabel,
  ) {
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
          divisions: _sliderDivisions(min, max),
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
