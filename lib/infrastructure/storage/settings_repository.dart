import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/app_settings.dart';

/// 設定リポジトリ
class SettingsRepository {
  static const String _key = 'app_settings';

  /// 設定を読み込み
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) {
      return const AppSettings(); // デフォルト設定
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (e) {
      // パースエラー時はデフォルト設定を返す
      return const AppSettings();
    }
  }

  /// 設定を保存
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_key, jsonString);
  }

  /// 設定を削除（デフォルトに戻す）
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
