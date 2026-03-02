import 'package:flutter_test/flutter_test.dart';
import 'package:walk_walk/domain/models/app_settings.dart';

void main() {
  group('AppSettings.useEmbeddedTts', () {
    test('defaults to false', () {
      const settings = AppSettings();
      expect(settings.useEmbeddedTts, isFalse);
    });

    test('can be enabled via copyWith', () {
      const settings = AppSettings();
      final updated = settings.copyWith(useEmbeddedTts: true);
      expect(updated.useEmbeddedTts, isTrue);
    });

    test('is preserved through toJson/fromJson', () {
      final original = const AppSettings().copyWith(useEmbeddedTts: true);
      final json = original.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.useEmbeddedTts, isTrue);
    });
  });

  group('AppSettings.ttsVoice', () {
    test('defaults to null', () {
      const settings = AppSettings();
      expect(settings.ttsVoice, isNull);
    });

    test('can be set via copyWith', () {
      const settings = AppSettings();
      const voice = {'name': 'Kyoko', 'locale': 'ja-JP'};
      final updated = settings.copyWith(ttsVoice: voice);
      expect(updated.ttsVoice, voice);
    });

    test('can be cleared via copyWith(ttsVoice: null)', () {
      const settings = AppSettings();
      final withVoice = settings.copyWith(ttsVoice: {'name': 'Kyoko', 'locale': 'ja-JP'});
      expect(withVoice.ttsVoice, isNotNull);
      final cleared = withVoice.copyWith(ttsVoice: null);
      expect(cleared.ttsVoice, isNull);
    });

    test('is preserved through toJson/fromJson', () {
      const voice = {'identifier': 'com.apple.voice.compact.ja-JP.Kyoko', 'name': 'Kyoko', 'locale': 'ja-JP'};
      final original = const AppSettings().copyWith(ttsVoice: voice);
      final json = original.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.ttsVoice, voice);
    });
  });
}

