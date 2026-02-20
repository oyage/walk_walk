import '../models/nearby_context.dart';
import '../models/app_settings.dart';

/// 案内文章フォーマッターのインターフェース
abstract class GuidanceFormatter {
  /// 周辺情報から案内文章を生成
  String format(NearbyContext context, AppSettings settings);
}
