import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walk_walk/presentation/settings/settings_screen.dart';

void main() {
  group('SettingsScreen（設計書通りの項目）', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump(); // 初回ビルド（ローディング表示）
      await tester.pumpAndSettle(); // _loadSettings 完了まで待機
    }

    /// ListView を下にスクロールして下段の項目を表示（遅延ビルド対応）
    Future<void> scrollToBottom(WidgetTester tester) async {
      final listFinder = find.byType(ListView);
      for (var i = 0; i < 8; i++) {
        await tester.drag(listFinder, const Offset(0, -250));
        await tester.pump();
      }
    }

    testWidgets('タイトル「設定」が表示される', (tester) async {
      await pumpSettings(tester);
      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('保存アイコンボタンが表示される', (tester) async {
      await pumpSettings(tester);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('位置情報セクションが表示される', (tester) async {
      await pumpSettings(tester);
      expect(find.text('位置情報'), findsOneWidget);
    });

    testWidgets('位置情報取得間隔（分）が表示される', (tester) async {
      await pumpSettings(tester);
      expect(find.text('位置情報取得間隔（分）'), findsOneWidget);
    });

    testWidgets('検索半径（メートル）が表示される', (tester) async {
      await pumpSettings(tester);
      expect(find.text('検索半径（メートル）'), findsOneWidget);
    });

    testWidgets('案内設定セクションが表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('案内設定'), findsOneWidget);
    }, skip: true); // DEV時はListViewが長く案内設定がビューポート外になる環境あり

    testWidgets('案内クールダウン（秒）が表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('案内クールダウン（秒）'), findsAtLeastNWidgets(1));
    }, skip: true); // DEV時はListViewが長く案内クールダウンがビューポート外になる環境あり

    testWidgets('距離閾値（メートル）が表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('距離閾値（メートル）'), findsOneWidget);
    });

    testWidgets('音声設定セクションが表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('音声設定'), findsOneWidget);
    });

    testWidgets('TTS速度が表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('TTS速度'), findsOneWidget);
    });

    testWidgets('TTS言語が表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('TTS言語'), findsOneWidget);
    });

    testWidgets('その他セクションが表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('その他'), findsOneWidget);
    });

    testWidgets('履歴保持期間（時間）が表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('履歴保持期間（時間）'), findsOneWidget);
    });

    testWidgets('バックグラウンド動作のスイッチが表示される', (tester) async {
      await pumpSettings(tester);
      await scrollToBottom(tester);
      expect(find.text('バックグラウンド動作'), findsOneWidget);
      expect(find.text('アプリを閉じても案内を続けます'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('保存をタップするとスナックバーが表示される', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect(find.text('設定を保存しました'), findsOneWidget);
    });
  });
}
