import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:piper_tts/piper_tts.dart';
import '../../domain/models/app_settings.dart';

enum _TtsEngineType {
  system,
  embedded,
}

/// TTSサービス
class TtsService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  AudioPlayer? _audioPlayer;
  bool _embeddedInitialized = false;
  _TtsEngineType? _lastEngine;

  bool _supportsEmbeddedTts() {
    // piper_tts が対応しているプラットフォームのみ true
    try {
      return Platform.isAndroid || Platform.isLinux || Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  bool _shouldUseEmbeddedTts(AppSettings settings) {
    return settings.useEmbeddedTts && _supportsEmbeddedTts();
  }

  /// TTSを初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initializeFlutterTts();
  }

  Future<void> _initializeFlutterTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage('ja');
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);

    // コールバックを設定して読み上げ状態を追跡
    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  Future<void> _initializeEmbeddedTts() async {
    if (_embeddedInitialized) return;
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      _isSpeaking = false;
    });
    _embeddedInitialized = true;
  }

  /// テキストを読み上げ
  Future<void> speak(String text, AppSettings settings) async {
    if (_shouldUseEmbeddedTts(settings)) {
      await _speakWithEmbeddedTts(text);
    } else {
      await _speakWithSystemTts(text, settings);
    }
  }

  /// 読み上げを停止
  Future<void> stop() async {
    switch (_lastEngine) {
      case _TtsEngineType.embedded:
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
        }
        break;
      case _TtsEngineType.system:
      case null:
        if (_flutterTts != null) {
          await _flutterTts!.stop();
        }
        break;
    }
    _isSpeaking = false;
  }

  /// 読み上げ中かどうか
  Future<bool> isSpeaking() async {
    return _isSpeaking;
  }

  Future<void> _speakWithSystemTts(String text, AppSettings settings) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_flutterTts == null) {
      throw Exception('TTSが初期化されていません');
    }

    _lastEngine = _TtsEngineType.system;
    await _flutterTts!.setLanguage(settings.ttsLanguage);
    await _flutterTts!.setSpeechRate(settings.ttsSpeechRate);
    _isSpeaking = true;
    await _flutterTts!.speak(text);
  }

  Future<void> _speakWithEmbeddedTts(String text) async {
    await _initializeEmbeddedTts();
    if (_audioPlayer == null) {
      throw Exception('埋め込みTTSの初期化に失敗しました');
    }

    _lastEngine = _TtsEngineType.embedded;
    _isSpeaking = true;

    // Piper で音声を生成して、ローカルファイルとして再生
    final file = await Piper.generateSpeech(text);
    final source = DeviceFileSource(file.path);

    await _audioPlayer!.stop();
    await _audioPlayer!.play(source);
  }
}
