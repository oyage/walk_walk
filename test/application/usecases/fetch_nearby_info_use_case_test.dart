import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:walk_walk/domain/models/geo_point.dart';
import 'package:walk_walk/domain/models/poi_candidate.dart';
import 'package:walk_walk/domain/services/geocoding_provider.dart';
import 'package:walk_walk/domain/services/places_provider.dart';
import 'package:walk_walk/application/usecases/fetch_nearby_info_use_case.dart';
import 'package:walk_walk/infrastructure/storage/cache_repository.dart';

void main() {
  late MockGeocodingProvider mockGeocoding;
  late MockPlacesProvider mockPlaces;
  late MockCacheRepository mockCache;

  setUpAll(() {
    registerFallbackValue(const GeoPoint(lat: 0, lng: 0));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockGeocoding = MockGeocodingProvider();
    mockPlaces = MockPlacesProvider();
    mockCache = MockCacheRepository();
  });

  group('FetchNearbyInfoUseCase', () {
    const point = GeoPoint(lat: 35.6812, lng: 139.7671);
    const searchRadiusMeters = 500;

    test('キャッシュが無い場合はAPIを呼びNearbyContextを返す', () async {
      when(() => mockCache.getGeocodeCache(any())).thenAnswer((_) async => null);
      when(() => mockCache.getPlacesCache(any())).thenAnswer((_) async => null);
      when(() => mockCache.setGeocodeCache(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockCache.setPlacesCache(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockGeocoding.reverseGeocode(any()))
          .thenAnswer((_) async => '東京都渋谷区');
      when(() => mockPlaces.searchNearby(
            point: any(named: 'point'),
            radiusMeters: any(named: 'radiusMeters'),
            categories: any(named: 'categories'),
          )).thenAnswer((_) async => [
        const PoiCandidate(
          name: '渋谷駅',
          category: 'train_station',
          distanceMeters: 200,
          sourceId: 'chiyoda',
        ),
      ]);

      final useCase = FetchNearbyInfoUseCase(
        mockGeocoding,
        mockPlaces,
        mockCache,
      );

      final result = await useCase.fetchNearbyInfo(point, searchRadiusMeters);

      expect(result.areaName, '東京都渋谷区');
      expect(result.landmarks.length, 1);
      expect(result.landmarks.first.name, '渋谷駅');
      verify(() => mockGeocoding.reverseGeocode(point)).called(1);
      verify(() => mockPlaces.searchNearby(
            point: point,
            radiusMeters: searchRadiusMeters,
            categories: any(named: 'categories'),
          )).called(4);
    });

    test('2回目はキャッシュから返しAPIは呼ばない', () async {
      var getGeocodeCalls = 0;
      var getPlacesCalls = 0;
      when(() => mockCache.getGeocodeCache(any())).thenAnswer((_) async {
        getGeocodeCalls++;
        return getGeocodeCalls == 1 ? null : '東京都千代田区';
      });
      when(() => mockCache.getPlacesCache(any())).thenAnswer((_) async {
        getPlacesCalls++;
        if (getPlacesCalls == 1) return null;
        return '[{"name":"皇居","category":"park","distanceMeters":100,"sourceId":null}]';
      });
      when(() => mockCache.setGeocodeCache(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockCache.setPlacesCache(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockGeocoding.reverseGeocode(any()))
          .thenAnswer((_) async => '東京都千代田区');
      when(() => mockPlaces.searchNearby(
            point: any(named: 'point'),
            radiusMeters: any(named: 'radiusMeters'),
            categories: any(named: 'categories'),
          )).thenAnswer((_) async => [
        const PoiCandidate(
          name: '皇居',
          category: 'park',
          distanceMeters: 100,
          sourceId: null,
        ),
      ]);

      final useCase = FetchNearbyInfoUseCase(
        mockGeocoding,
        mockPlaces,
        mockCache,
      );

      final result1 = await useCase.fetchNearbyInfo(point, searchRadiusMeters);
      final result2 = await useCase.fetchNearbyInfo(point, searchRadiusMeters);

      expect(result1.areaName, result2.areaName);
      expect(result2.areaName, '東京都千代田区');
      expect(result2.landmarks.first.name, '皇居');
      verify(() => mockGeocoding.reverseGeocode(point)).called(1);
      verify(() => mockPlaces.searchNearby(
            point: point,
            radiusMeters: searchRadiusMeters,
            categories: any(named: 'categories'),
          )).called(4);
    });

    test('skipCache: true の場合はキャッシュを読まず常にAPIを呼ぶ', () async {
      when(() => mockCache.getGeocodeCache(any())).thenAnswer((_) async => null);
      when(() => mockCache.getPlacesCache(any())).thenAnswer((_) async => null);
      when(() => mockCache.setGeocodeCache(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockCache.setPlacesCache(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockGeocoding.reverseGeocode(any()))
          .thenAnswer((_) async => 'APIの地域名');
      when(() => mockPlaces.searchNearby(
            point: any(named: 'point'),
            radiusMeters: any(named: 'radiusMeters'),
            categories: any(named: 'categories'),
          )).thenAnswer((_) async => [
        const PoiCandidate(
          name: 'APIのPOI',
          category: 'cafe',
          distanceMeters: 100,
          sourceId: null,
        ),
      ]);

      final useCase = FetchNearbyInfoUseCase(
        mockGeocoding,
        mockPlaces,
        mockCache,
      );

      final result = await useCase.fetchNearbyInfo(
        point,
        searchRadiusMeters,
        skipCache: true,
      );

      expect(result.areaName, 'APIの地域名');
      expect(result.shops.length, greaterThanOrEqualTo(3)); // 4 types で検索しマージするため3件以上
      expect(result.shops.first.name, 'APIのPOI');
      verify(() => mockGeocoding.reverseGeocode(point)).called(1);
      verify(() => mockPlaces.searchNearby(
            point: point,
            radiusMeters: searchRadiusMeters,
            categories: any(named: 'categories'),
          )).called(4);

      when(() => mockGeocoding.reverseGeocode(any()))
          .thenAnswer((_) async => '別の地域');
      final result2 = await useCase.fetchNearbyInfo(
        point,
        searchRadiusMeters,
        skipCache: true,
      );
      expect(result2.areaName, '別の地域');
    });

    test('POI検索でネットワークエラー時は例外を再スローする', () async {
      when(() => mockCache.getGeocodeCache(any())).thenAnswer((_) async => null);
      when(() => mockCache.getPlacesCache(any())).thenAnswer((_) async => null);
      when(() => mockCache.setGeocodeCache(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockGeocoding.reverseGeocode(any()))
          .thenAnswer((_) async => '東京都');
      when(() => mockPlaces.searchNearby(
            point: any(named: 'point'),
            radiusMeters: any(named: 'radiusMeters'),
            categories: any(named: 'categories'),
          )).thenThrow(
        ClientException('Failed host lookup: \'maps.googleapis.com\''),
      );

      final useCase = FetchNearbyInfoUseCase(
        mockGeocoding,
        mockPlaces,
        mockCache,
      );

      expect(
        () => useCase.fetchNearbyInfo(point, searchRadiusMeters),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('接続できません'),
        )),
      );
    });
  });
}

class MockGeocodingProvider extends Mock implements GeocodingProvider {}

class MockPlacesProvider extends Mock implements PlacesProvider {}

class MockCacheRepository extends Mock implements CacheRepository {}
