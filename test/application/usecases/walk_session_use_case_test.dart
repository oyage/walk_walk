import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walk_walk/application/usecases/walk_session_use_case.dart';
import 'package:walk_walk/application/usecases/fetch_nearby_info_use_case.dart';
import 'package:walk_walk/domain/models/app_settings.dart';
import 'package:walk_walk/domain/models/guidance_message.dart';
import 'package:walk_walk/domain/models/location_sample.dart';
import 'package:walk_walk/domain/models/geo_point.dart';
import 'package:walk_walk/domain/models/nearby_context.dart';
import 'package:walk_walk/domain/services/guidance_formatter.dart';
import 'package:walk_walk/infrastructure/location/location_service.dart';
import 'package:walk_walk/infrastructure/storage/guidance_history_repository.dart';
import 'package:walk_walk/infrastructure/storage/settings_repository.dart';
import 'package:walk_walk/infrastructure/tts/tts_service.dart';

class MockLocationService extends Mock implements LocationService {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockGuidanceHistoryRepository extends Mock
    implements GuidanceHistoryRepository {}

class MockTtsService extends Mock implements TtsService {}

class MockGuidanceFormatter extends Mock implements GuidanceFormatter {}

class MockFetchNearbyInfoUseCase extends Mock implements FetchNearbyInfoUseCase {}

void main() {
  late MockLocationService mockLocation;
  late MockSettingsRepository mockSettings;
  late MockGuidanceHistoryRepository mockHistory;
  late MockTtsService mockTts;
  late MockGuidanceFormatter mockFormatter;
  late MockFetchNearbyInfoUseCase mockFetchNearby;

  final sampleLocation = LocationSample(
    point: const GeoPoint(lat: 35.6812, lng: 139.7671),
    timestamp: DateTime(2025, 1, 1, 12, 0),
    accuracy: 10,
    altitude: null,
  );

  const foregroundSettings = AppSettings(enableBackgroundMode: false);
  const backgroundSettings = AppSettings(enableBackgroundMode: true);

  setUpAll(() {
    registerFallbackValue(const GeoPoint(lat: 0, lng: 0));
    registerFallbackValue(const AppSettings());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(GuidanceMessage(
      id: '',
      guidedPlaces: [],
      createdAt: DateTime(0),
      point: const GeoPoint(lat: 0, lng: 0),
      tags: [],
    ));
    registerFallbackValue(const NearbyContext(
      areaName: null,
      landmarks: [],
      shops: [],
    ));
  });

  setUp(() {
    mockLocation = MockLocationService();
    mockSettings = MockSettingsRepository();
    mockHistory = MockGuidanceHistoryRepository();
    mockTts = MockTtsService();
    mockFormatter = MockGuidanceFormatter();
    mockFetchNearby = MockFetchNearbyInfoUseCase();
  });

  void stubCommonCalls() {
    when(() => mockLocation.getPermissionStatus())
        .thenAnswer((_) async => LocationPermissionStatus.whileInUse);
    when(() => mockLocation.getCurrentLocation())
        .thenAnswer((_) async => sampleLocation);
    when(() => mockLocation.hasTestLocation()).thenAnswer((_) async => false);
    when(() => mockHistory.getRecentMessages(limit: any(named: 'limit')))
        .thenAnswer((_) async => <GuidanceMessage>[]);
    when(() => mockHistory.addMessage(any())).thenAnswer((_) async {});
    when(() => mockFetchNearby.fetchNearbyInfo(
          any(),
          any(),
          skipCache: any(named: 'skipCache'),
        )).thenAnswer((_) async => const NearbyContext(
          areaName: '東京都',
          landmarks: [],
          shops: [],
        ));
    when(() => mockFormatter.format(any(), any())).thenReturn('案内テキスト');
    when(() => mockTts.speak(any(), any())).thenAnswer((_) async {});
  }

  /// 検証: お散歩開始時に getCurrentLocation が1回だけ呼ばれること。
  /// - 前景モード: 本テストで自動検証。
  /// - バックグラウンドモード: 実機で「お散歩開始」1回→案内1回のみであることを目視確認。
  group('WalkSessionUseCase start location fetch count', () {
    test('foreground mode: getCurrentLocation called once on start', () async {
      when(() => mockSettings.load())
          .thenAnswer((_) async => foregroundSettings);
      stubCommonCalls();

      final useCase = WalkSessionUseCase(
        mockLocation,
        mockSettings,
        mockHistory,
        mockTts,
        mockFormatter,
        mockFetchNearby,
      );

      await useCase.start();

      verify(() => mockLocation.getCurrentLocation()).called(1);
    });

    test('background mode: getCurrentLocation called once on start',
        () async {
      when(() => mockSettings.load())
          .thenAnswer((_) async => backgroundSettings);
      when(() => mockLocation.getLocationStream(
            intervalSeconds: any(named: 'intervalSeconds'),
          )).thenAnswer((_) => Stream<LocationSample>.empty());
      stubCommonCalls();

      final useCase = WalkSessionUseCase(
        mockLocation,
        mockSettings,
        mockHistory,
        mockTts,
        mockFormatter,
        mockFetchNearby,
      );

      await useCase.start();

      verify(() => mockLocation.getCurrentLocation()).called(1);
    }, skip: 'BackgroundWorker uses NotificationService (plugin not initialized in test)');
  });

}
