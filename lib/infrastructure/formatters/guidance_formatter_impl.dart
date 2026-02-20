import '../../domain/models/nearby_context.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/services/guidance_formatter.dart';

/// 案内文章フォーマッター実装
class GuidanceFormatterImpl implements GuidanceFormatter {
  @override
  String format(NearbyContext context, AppSettings settings) {
    final buffer = StringBuffer();

    // 地域名
    if (context.areaName != null && context.areaName!.isNotEmpty) {
      buffer.write('現在、${context.areaName}にいます。');
    } else {
      buffer.write('現在地周辺の情報をお伝えします。');
    }

    // ランドマーク
    if (context.hasLandmarks) {
      buffer.write('近くには');
      final landmarkNames = context.landmarks.map((l) => l.name).toList();
      if (landmarkNames.length == 1) {
        buffer.write('${landmarkNames[0]}があります。');
      } else if (landmarkNames.length == 2) {
        buffer.write('${landmarkNames[0]}と${landmarkNames[1]}があります。');
      } else {
        buffer.write(
          '${landmarkNames[0]}、${landmarkNames[1]}、${landmarkNames[2]}があります。',
        );
      }
    }

    // 店舗
    if (context.hasShops) {
      if (context.hasLandmarks) {
        buffer.write('また、');
      }
      final shopNames = context.shops.map((s) => s.name).toList();
      if (shopNames.length == 1) {
        buffer.write('${shopNames[0]}も近くにあります。');
      } else if (shopNames.length == 2) {
        buffer.write('${shopNames[0]}と${shopNames[1]}も近くにあります。');
      } else {
        buffer.write(
          '${shopNames[0]}、${shopNames[1]}、${shopNames[2]}も近くにあります。',
        );
      }
    }

    // 何も情報がない場合
    if (!context.hasLandmarks && !context.hasShops) {
      buffer.write('周辺に特に目立った施設はありません。');
    }

    return buffer.toString();
  }
}
