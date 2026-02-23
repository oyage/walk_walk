import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walk_walk/application/state/location_state.dart';
import 'package:walk_walk/application/state/walk_session_state.dart';
import 'package:walk_walk/application/usecases/walk_session_use_case.dart';
import 'package:walk_walk/domain/models/geo_point.dart';
import 'package:walk_walk/domain/models/location_sample.dart';
import 'package:walk_walk/infrastructure/location/location_service.dart';
import 'package:walk_walk/presentation/home/home_screen.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(const GeoPoint(lat: 0, lng: 0));
  });

  group('HomeScreen（設計書通りのUI）', () {
    late MockLocationService mockLocationService;
    late MockWalkSessionUseCase mockWalkSessionUseCase;

    setUp(() {
      mockLocationService = MockLocationService();
      mockWalkSessionUseCase = MockWalkSessionUseCase();
      when(() => mockWalkSessionUseCase.start()).thenAnswer((_) async {});
      when(() => mockWalkSessionUseCase.stop()).thenAnswer((_) async {});
      when(() => mockWalkSessionUseCase.performGuidance()).thenAnswer((_) async {});
      when(() => mockLocationService.openAppSettings()).thenAnswer((_) async => false);
    });

    Future<void> pumpHome(WidgetTester tester, {CurrentLocationState? locationState, WalkSessionState? walkState}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLocationProvider.overrideWith(
              (ref) => _FakeCurrentLocationNotifier(
                locationState ?? const CurrentLocationState(),
                mockLocationService,
              ),
            ),
            walkSessionStateProvider.overrideWith(
              (ref) => _FakeWalkSessionNotifier(
                walkState ?? const WalkSessionState(),
                mockWalkSessionUseCase,
              ),
            ),
            guidanceHistoryProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('アプリタイトル「Walk Walk」が表示される', (tester) async {
      await pumpHome(tester);
      expect(find.text('Walk Walk'), findsOneWidget);
    });

    testWidgets('現在地セクションが表示される', (tester) async {
      await pumpHome(tester);
      expect(find.text('現在地'), findsOneWidget);
    });

    testWidgets('位置情報未取得時は「位置情報を取得できませんでした」が表示される', (tester) async {
      await pumpHome(tester);
      expect(find.text('位置情報を取得できませんでした'), findsOneWidget);
    });

    testWidgets('位置情報取得成功時は緯度・経度が表示される', (tester) async {
      final sample = LocationSample(
        point: const GeoPoint(lat: 35.6812, lng: 139.7671),
        timestamp: DateTime(2020, 1, 1),
      );
      await pumpHome(
        tester,
        locationState: CurrentLocationState(
          location: sample,
          isLoading: false,
        ),
      );
      expect(find.textContaining('緯度: 35.681200'), findsOneWidget);
      expect(find.textContaining('経度: 139.767100'), findsOneWidget);
    });

    testWidgets('「お散歩開始」ボタンが表示される', (tester) async {
      await pumpHome(tester);
      expect(find.text('お散歩開始'), findsOneWidget);
    });

    testWidgets('お散歩中は「お散歩停止」ボタンと状態表示が出る', (tester) async {
      await pumpHome(
        tester,
        walkState: const WalkSessionState(isRunning: true),
      );
      expect(find.text('お散歩停止'), findsOneWidget);
      expect(find.text('お散歩中 - 案内を待っています...'), findsOneWidget);
    });

    testWidgets('「案内履歴」セクションが表示される', (tester) async {
      await pumpHome(tester);
      expect(find.text('案内履歴'), findsOneWidget);
    });

    testWidgets('案内履歴が空のとき「案内履歴がありません」が表示される', (tester) async {
      await pumpHome(tester);
      expect(find.text('案内履歴がありません'), findsOneWidget);
    });

    testWidgets('設定アイコンをタップすると設定画面へ遷移する', (tester) async {
      await pumpHome(tester);
      final appBarSettingsIcon = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(appBarSettingsIcon);
      await tester.pumpAndSettle();
      expect(find.text('設定'), findsWidgets);
    });
  });
}

class _FakeCurrentLocationNotifier extends CurrentLocationNotifier {
  _FakeCurrentLocationNotifier(CurrentLocationState initialState, LocationService service)
      : super(service) {
    state = initialState;
  }
}

class _FakeWalkSessionNotifier extends WalkSessionNotifier {
  _FakeWalkSessionNotifier(WalkSessionState initialState, WalkSessionUseCase useCase)
      : super(useCase) {
    state = initialState;
  }
}

class MockLocationService extends Mock implements LocationService {}

class MockWalkSessionUseCase extends Mock implements WalkSessionUseCase {}
