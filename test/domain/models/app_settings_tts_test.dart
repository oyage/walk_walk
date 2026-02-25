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
}

