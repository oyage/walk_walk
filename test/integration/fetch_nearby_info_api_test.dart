@Tags(['integration'])
library;
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:test/test.dart';
import 'package:walk_walk/application/usecases/fetch_nearby_info_use_case.dart';
import 'package:walk_walk/domain/models/geo_point.dart';
import 'package:walk_walk/infrastructure/external/geocoding/google_geocoding_provider.dart';
import 'package:walk_walk/infrastructure/external/places/google_places_provider.dart';
import 'package:walk_walk/infrastructure/storage/cache_repository.dart';
import 'package:walk_walk/infrastructure/storage/database.dart';

void main() {
  late FetchNearbyInfoUseCase useCase;

  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      markTestSkipped('Create .env with GOOGLE_PLACES_API_KEY to run integration tests');
    }
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      markTestSkipped('Set GOOGLE_PLACES_API_KEY in .env to run integration tests');
    }
  });

  setUp(() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = CacheRepository(db);
    final geocoding = GoogleGeocodingProvider();
    final places = GooglePlacesProvider();
    useCase = FetchNearbyInfoUseCase(geocoding, places, cache);
  });

  group('FetchNearbyInfoUseCase (real API)', () {
    test('実APIで周辺情報を取得できる', () async {
      const point = GeoPoint(lat: 35.6812, lng: 139.7671);
      const searchRadiusMeters = 500;

      final result = await useCase.fetchNearbyInfo(point, searchRadiusMeters);

      expect(result.areaName, isNotNull);
      expect(result.areaName!.isNotEmpty, isTrue);
      expect(result.landmarks, isA<List>());
      expect(result.shops, isA<List>());
    });
  });
}
