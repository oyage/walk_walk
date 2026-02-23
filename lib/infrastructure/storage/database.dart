import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// 逆ジオコーディングキャッシュテーブル
class GeocodeCaches extends Table {
  TextColumn get key => text()(); // ジオハッシュ
  TextColumn get areaName => text()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// POIキャッシュテーブル
class PlacesCaches extends Table {
  TextColumn get key => text()(); // geohash-radius
  TextColumn get poisJson => text()(); // JSON文字列
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 案内メッセージテーブル
class GuidanceMessages extends Table {
  TextColumn get id => text()();
  TextColumn get messageText => text()();
  DateTimeColumn get createdAt => dateTime()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  // 空文字で未設定を表現（読み取り時に null として扱う）
  TextColumn get areaName => text()();
  TextColumn get tagsJson => text()(); // JSON配列文字列

  @override
  Set<Column> get primaryKey => {id};
}

/// アプリデータベース
@DriftDatabase(tables: [GeocodeCaches, PlacesCaches, GuidanceMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// テスト用：メモリ上でDBを開く（外部から executor を渡す）
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 将来のマイグレーション処理
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'walk_walk.db'));
    return NativeDatabase(file);
  });
}
