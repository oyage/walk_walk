import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知サービス
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// 通知サービスを初期化
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android通知チャネルを作成
    const androidChannel = AndroidNotificationChannel(
      'walk_walk_channel',
      'Walk Walk Notifications',
      description: 'お散歩案内の通知',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 通知がタップされた時の処理
  static void _onNotificationTapped(NotificationResponse response) {
    // 必要に応じて処理を追加
  }

  /// 通知を表示
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'walk_walk_channel',
      'Walk Walk Notifications',
      channelDescription: 'お散歩案内の通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// 通知をキャンセル
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id: id);
  }

  /// すべての通知をキャンセル
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
