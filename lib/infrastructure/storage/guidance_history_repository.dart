import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/models/guidance_message.dart' as domain;
import '../../domain/models/geo_point.dart';
import '../../domain/models/app_settings.dart';
import 'database.dart' hide GuidanceMessage;

/// 案内履歴の保存・読み込み
class GuidanceHistoryRepository {
  final AppDatabase _db;

  GuidanceHistoryRepository(this._db);

  /// 案内メッセージを保存（guidedPlaces を JSON 配列 [{"name","url"}] で messageText に格納）
  Future<void> addMessage(domain.GuidanceMessage message) async {
    final payload = message.guidedPlaces
        .map((p) => <String, String>{'name': p.name, 'url': p.url})
        .toList();
    await _db.into(_db.guidanceMessages).insert(
          GuidanceMessagesCompanion.insert(
            id: message.id,
            messageText: jsonEncode(payload),
            createdAt: message.createdAt,
            lat: message.point.lat,
            lng: message.point.lng,
            areaName: message.areaName ?? '',
            tagsJson: jsonEncode(message.tags),
          ),
        );
  }

  /// 最新N件の履歴を取得
  Future<List<domain.GuidanceMessage>> getRecentMessages({int limit = 20}) async {
    final rows = await (_db.select(_db.guidanceMessages)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.createdAt,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
        .get();

    return rows.map((row) {
      List<String> tags = [];
      try {
        final tagsJson = jsonDecode(row.tagsJson) as List?;
        tags = tagsJson?.map((e) => e.toString()).toList() ?? [];
      } catch (e) {
        // JSONパースエラー時は空リスト
      }

      List<domain.GuidedPlace> guidedPlaces = [];
      try {
        final decoded = jsonDecode(row.messageText);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map<String, dynamic>) {
              guidedPlaces.add(domain.GuidedPlace(
                name: (e['name'] as String?) ?? '',
                url: (e['url'] as String?) ?? '',
              ));
            } else if (e is String) {
              // 旧形式: URL のみの配列
              guidedPlaces.add(domain.GuidedPlace(name: '', url: e));
            }
          }
        }
      } catch (e) {
        // 旧形式（案内文テキスト）やパースエラー時は空リスト
      }

      return domain.GuidanceMessage(
        id: row.id,
        guidedPlaces: guidedPlaces,
        createdAt: row.createdAt,
        point: GeoPoint(lat: row.lat, lng: row.lng),
        areaName: row.areaName.isEmpty ? null : row.areaName,
        tags: tags,
      );
    }).toList();
  }

  /// 指定時間より古いメッセージを削除
  Future<int> deleteOlderThan(DateTime threshold) async {
    return await (_db.delete(_db.guidanceMessages)
          ..where((tbl) => tbl.createdAt.isSmallerThanValue(threshold)))
        .go();
  }

  /// 案内履歴をすべて削除（DEV・デバッグ用）
  Future<void> deleteAllMessages() async {
    await _db.delete(_db.guidanceMessages).go();
  }

  /// 設定に基づいて古いデータを自動削除
  Future<int> cleanupOldMessages(AppSettings settings) async {
    final threshold = DateTime.now()
        .subtract(Duration(hours: settings.historyRetentionHours));
    return await deleteOlderThan(threshold);
  }
}
