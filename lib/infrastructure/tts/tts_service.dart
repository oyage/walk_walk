import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/models/app_settings.dart';

/// TTSサービス
class TtsService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  /// TTSを初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage('ja');
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);

    _isInitialized = true;
  }

  /// テキストを読み上げ
  Future<void> speak(String text, AppSettings settings) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_flutterTts == null) {
      throw Exception('TTSが初期化されていません');
    }

    await _flutterTts!.setLanguage(settings.ttsLanguage);
    await _flutterTts!.setSpeechRate(settings.ttsSpeechRate);
    await _flutterTts!.speak(text);
  }

  /// 読み上げを停止
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  /// 読み上げ中かどうか
  Future<bool> isSpeaking() async {
    if (_flutterTts == null) return false;
    return await _flutterTts!.isSpeaking ?? false;
  }
}
