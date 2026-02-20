import 'package:drift/drift.dart';
import 'database.dart';

/// キャッシュ（逆ジオコーディング・POI）の管理
class CacheRepository {
  final AppDatabase _db;

  CacheRepository(this._db);

  /// 逆ジオコーディングキャッシュを取得
  Future<String?> getGeocodeCache(String key) async {
    final cache = await (_db.select(_db.geocodeCaches)
          ..where((tbl) => tbl.key.equals(key))
          ..where((tbl) => tbl.expiresAt.isBiggerThanValue(DateTime.now())))
        .getSingleOrNull();

    return cache?.areaName;
  }

  /// 逆ジオコーディングキャッシュを保存
  Future<void> setGeocodeCache(
    String key,
    String areaName,
    Duration ttl,
  ) async {
    final expiresAt = DateTime.now().add(ttl);
    await _db.into(_db.geocodeCaches).insertOnConflictUpdate(
          GeocodeCachesCompanion.insert(
            key: key,
            areaName: areaName,
            expiresAt: expiresAt,
          ),
        );
  }

  /// POIキャッシュを取得
  Future<String?> getPlacesCache(String key) async {
    final cache = await (_db.select(_db.placesCaches)
          ..where((tbl) => tbl.key.equals(key))
          ..where((tbl) => tbl.expiresAt.isBiggerThanValue(DateTime.now())))
        .getSingleOrNull();

    return cache?.poisJson;
  }

  /// POIキャッシュを保存
  Future<void> setPlacesCache(
    String key,
    String poisJson,
    Duration ttl,
  ) async {
    final expiresAt = DateTime.now().add(ttl);
    await _db.into(_db.placesCaches).insertOnConflictUpdate(
          PlacesCachesCompanion.insert(
            key: key,
            poisJson: poisJson,
            expiresAt: expiresAt,
          ),
        );
  }

  /// 期限切れキャッシュを削除
  Future<void> cleanupExpiredCache() async {
    final now = DateTime.now();
    await (_db.delete(_db.geocodeCaches)
          ..where((tbl) => tbl.expiresAt.isSmallerThanValue(now)))
        .go();
    await (_db.delete(_db.placesCaches)
          ..where((tbl) => tbl.expiresAt.isSmallerThanValue(now)))
        .go();
  }
}
