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

  /// 案内メッセージを保存
  Future<void> addMessage(domain.GuidanceMessage message) async {
    await _db.into(_db.guidanceMessages).insert(
          GuidanceMessagesCompanion.insert(
            id: message.id,
            messageText: message.text,
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

      return domain.GuidanceMessage(
        id: row.id,
        text: row.messageText,
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

  /// 設定に基づいて古いデータを自動削除
  Future<int> cleanupOldMessages(AppSettings settings) async {
    final threshold = DateTime.now()
        .subtract(Duration(hours: settings.historyRetentionHours));
    return await deleteOlderThan(threshold);
  }
}
