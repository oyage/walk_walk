import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/state/location_state.dart';
import '../../application/state/walk_session_state.dart';
import '../settings/settings_screen.dart';

/// ホーム画面
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(currentLocationProvider);
    final walkSessionState = ref.watch(walkSessionStateProvider);
    final guidanceHistoryAsync = ref.watch(guidanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk Walk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 現在地表示
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '現在地',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (locationState.isLoading)
                    const CircularProgressIndicator()
                  else if (locationState.error != null)
                    Text(
                      locationState.error!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else if (locationState.location != null)
                    Text(
                      '緯度: ${locationState.location!.point.lat.toStringAsFixed(6)}, '
                      '経度: ${locationState.location!.point.lng.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 16),
                    )
                  else
                    const Text('位置情報を取得できませんでした'),
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: locationState.isLoading
                              ? null
                              : () async {
                                  await ref
                                      .read(currentLocationProvider.notifier)
                                      .requestPermissionAndFetch();
                                },
                          icon: const Icon(Icons.location_on, size: 18),
                          label: const Text('権限をリクエストして再取得'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final opened = await ref
                                .read(currentLocationProvider.notifier)
                                .openAppSettings();
                            if (context.mounted && !opened) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'この端末では設定画面を開けません。'
                                    '端末の設定アプリから位置情報を許可してください。',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('設定を開く'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // セッション状態とエラー表示
          if (walkSessionState.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      walkSessionState.error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          // 開始/停止ボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: walkSessionState.isRunning
                    ? () => ref.read(walkSessionStateProvider.notifier).stop()
                    : () => ref.read(walkSessionStateProvider.notifier).start(),
                icon: Icon(
                  walkSessionState.isRunning ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(
                  walkSessionState.isRunning ? 'お散歩停止' : 'お散歩開始',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: walkSessionState.isRunning
                      ? Colors.red
                      : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          // セッション状態表示
          if (walkSessionState.isRunning)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'お散歩中 - 案内を待っています...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          // 履歴リスト
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '案内履歴',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: guidanceHistoryAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('案内履歴がありません'),
                  );
                }
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          message.tags.contains('landmark')
                              ? Icons.place
                              : Icons.store,
                        ),
                      ),
                      title: Text(message.text),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.areaName != null)
                            Text('場所: ${message.areaName}'),
                          Text(
                            DateFormat('yyyy/MM/dd HH:mm:ss')
                                .format(message.createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text('エラー: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
