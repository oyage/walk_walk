import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/home/home_screen.dart';
import 'infrastructure/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 環境変数を読み込み
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .envファイルがなくても続行（開発環境では必須）
    print('Warning: .env file not found: $e');
  }

  // 通知サービスを初期化
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: WalkWalkApp(),
    ),
  );
}

class WalkWalkApp extends StatelessWidget {
  const WalkWalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk Walk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
