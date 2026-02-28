import 'dart:convert';
import 'package:dart_geohash/dart_geohash.dart';
import '../../domain/models/geo_point.dart';
import '../../domain/models/nearby_context.dart';
import '../../domain/models/poi_candidate.dart';
import '../../domain/services/geocoding_provider.dart';
import '../../domain/services/places_provider.dart';
import '../../infrastructure/storage/cache_repository.dart';
import '../../infrastructure/logging/app_logger.dart';
import '../utils/network_error_util.dart';

/// 周辺情報取得ユースケース
class FetchNearbyInfoUseCase {
  final GeocodingProvider _geocodingProvider;
  final PlacesProvider _placesProvider;
  final CacheRepository _cacheRepository;

  FetchNearbyInfoUseCase(
    this._geocodingProvider,
    this._placesProvider,
    this._cacheRepository,
  );

  /// 周辺情報を取得（キャッシュ優先）。[skipCache] が true のときはキャッシュを使わず常にAPI検索を行う（テスト位置用）。
  Future<NearbyContext> fetchNearbyInfo(
    GeoPoint point,
    int searchRadiusMeters, {
    bool skipCache = false,
  }) async {
    // ジオハッシュでキャッシュキーを生成（経度、緯度の順序）
    final geoHasher = GeoHasher();
    final geohash = geoHasher.encode(point.lng, point.lat, precision: 8);

    // 逆ジオコーディング（skipCache でなければキャッシュ優先）
    String? areaName =
        skipCache ? null : await _cacheRepository.getGeocodeCache(geohash);
    if (areaName == null) {
      try {
        areaName = await _geocodingProvider.reverseGeocode(point);
        if (areaName != null && !skipCache) {
          await _cacheRepository.setGeocodeCache(
            geohash,
            areaName,
            const Duration(hours: 24),
          );
        }
      } catch (e, stackTrace) {
        AppLogger.w('逆ジオコーディングエラー', e, stackTrace);
        if (isNetworkDnsError(e)) {
          throw Exception(userFacingErrorMessage(e));
        }
      }
    }

    // POI検索（skipCache でなければキャッシュ優先）。v3: Places API (New) searchNearby に移行
    const _poiCacheKeyPrefix = 'v3';
    final cacheKey = '$_poiCacheKeyPrefix-$geohash-$searchRadiusMeters';
    String? cachedPoisJson =
        skipCache ? null : await _cacheRepository.getPlacesCache(cacheKey);
    List<PoiCandidate> pois = [];

    if (cachedPoisJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedPoisJson);
        pois = jsonList.map((json) {
          return PoiCandidate(
            name: json['name'] as String,
            category: json['category'] as String,
            distanceMeters: json['distanceMeters'] as int?,
            sourceId: json['sourceId'] as String?,
          );
        }).toList();
        AppLogger.d('POIキャッシュから取得: ${pois.length}件');
      } catch (e, stackTrace) {
        AppLogger.w('POIキャッシュの復元に失敗', e, stackTrace);
        pois = [];
      }
    }

    if (pois.isEmpty) {
      try {
        // Legacy Nearby Search の type には Table 1 のみ有効。
        // point_of_interest/establishment は Table 2 のため無効になり ZERO_RESULTS になりやすい。
        // Table 1 の store, restaurant, cafe, park で複数リクエストしてマージする。
        const types = ['store', 'restaurant', 'cafe', 'park'];
        final seenIds = <String>{};
        for (final t in types) {
          final list = await _placesProvider.searchNearby(
            point: point,
            radiusMeters: searchRadiusMeters,
            categories: [t],
          );
          for (final p in list) {
            final id = p.sourceId ?? '${p.name}_$t';
            if (seenIds.contains(id)) continue;
            seenIds.add(id);
            pois.add(p);
          }
        }
        if (!skipCache) {
          final poisJson = jsonEncode(pois.map((p) => {
                'name': p.name,
                'category': p.category,
                'distanceMeters': p.distanceMeters,
                'sourceId': p.sourceId,
              }).toList());
          await _cacheRepository.setPlacesCache(
            cacheKey,
            poisJson,
            const Duration(minutes: 30),
          );
          AppLogger.d('POI検索結果をキャッシュに保存: ${pois.length}件');
        }
      } catch (e, stackTrace) {
        AppLogger.e('POI検索エラー', e, stackTrace);
        if (isNetworkDnsError(e)) {
          throw Exception(userFacingErrorMessage(e));
        }
        pois = [];
      }
    }

    // 店舗: 飲食・コンビニのみ。それ以外はランドマーク扱い（建物・施設として案内に含める）
    const shopCategories = {'cafe', 'restaurant', 'convenience_store'};
    final shops = pois.where((p) => shopCategories.contains(p.category)).toList();
    // ランドマーク: 明示カテゴリ + 未分類（gas_station, bank, pharmacy 等）はフォールバックで landmarks に含める
    final landmarkCategories = {
      'park', 'train_station', 'point_of_interest', 'establishment', 'store',
      'museum', 'shopping_mall', 'supermarket', 'library', 'school', 'hospital',
    };
    final landmarks = pois.where((p) =>
      landmarkCategories.contains(p.category) || !shopCategories.contains(p.category),
    ).toList();

    // 案内候補のプールサイズ（履歴にない施設を優先して選ぶため多めに返す）
    const int candidatePoolSize = 10;
    return NearbyContext(
      areaName: areaName,
      landmarks: landmarks.take(candidatePoolSize).toList(),
      shops: shops.take(candidatePoolSize).toList(),
    );
  }
}
