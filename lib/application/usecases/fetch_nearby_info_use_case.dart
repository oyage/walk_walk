import 'dart:convert';
import 'package:dart_geohash/dart_geohash.dart';
import '../../domain/models/geo_point.dart';
import '../../domain/models/nearby_context.dart';
import '../../domain/models/poi_candidate.dart';
import '../../domain/services/geocoding_provider.dart';
import '../../domain/services/places_provider.dart';
import '../../infrastructure/storage/cache_repository.dart';
import '../../infrastructure/logging/app_logger.dart';

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

  /// 周辺情報を取得（キャッシュ優先）
  Future<NearbyContext> fetchNearbyInfo(
    GeoPoint point,
    int searchRadiusMeters,
  ) async {
    // ジオハッシュでキャッシュキーを生成（経度、緯度の順序）
    final geoHasher = GeoHasher();
    final geohash = geoHasher.encode(point.lng, point.lat, precision: 8);

    // 逆ジオコーディング（キャッシュチェック）
    String? areaName = await _cacheRepository.getGeocodeCache(geohash);
    if (areaName == null) {
      try {
        areaName = await _geocodingProvider.reverseGeocode(point);
        if (areaName != null) {
          // キャッシュに保存（TTL: 24時間）
          await _cacheRepository.setGeocodeCache(
            geohash,
            areaName,
            const Duration(hours: 24),
          );
        }
      } catch (e, stackTrace) {
        // エラー時はキャッシュがあればそれを使用、なければnull
        AppLogger.w('逆ジオコーディングエラー', e, stackTrace);
      }
    }

    // POI検索（キャッシュチェック）
    final cacheKey = '$geohash-$searchRadiusMeters';
    String? cachedPoisJson = await _cacheRepository.getPlacesCache(cacheKey);
    List<PoiCandidate> pois = [];

    if (cachedPoisJson != null) {
      try {
        // JSONからPoiCandidateリストに復元
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
        // キャッシュが壊れている場合は再取得
        pois = [];
      }
    }

    if (pois.isEmpty) {
      try {
        pois = await _placesProvider.searchNearby(
          point: point,
          radiusMeters: searchRadiusMeters,
        );
        // キャッシュに保存（TTL: 30分）
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
      } catch (e, stackTrace) {
        // エラー時は空リスト
        AppLogger.e('POI検索エラー', e, stackTrace);
        pois = [];
      }
    }

    // ランドマークと店舗に分類
    final landmarks = pois.where((p) => 
      p.category == 'park' || 
      p.category == 'train_station' ||
      p.category == 'point_of_interest'
    ).toList();
    final shops = pois.where((p) => 
      p.category == 'cafe' || 
      p.category == 'restaurant' ||
      p.category == 'convenience_store'
    ).toList();

    return NearbyContext(
      areaName: areaName,
      landmarks: landmarks.take(3).toList(),
      shops: shops.take(3).toList(),
    );
  }
}
