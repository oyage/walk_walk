import 'package:flutter/material.dart';

/// プライバシーポリシー・利用規約画面
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('プライバシーポリシー・利用規約'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'プライバシーポリシー'),
              Tab(text: '利用規約'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PrivacyPolicyTab(),
            _TermsOfServiceTab(),
          ],
        ),
      ),
    );
  }
}

class _PrivacyPolicyTab extends StatelessWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'プライバシーポリシー',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '最終更新日: 2026年2月21日',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            '1. 位置情報の取り扱い',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '本アプリは、お散歩案内機能を提供するために、ユーザーの位置情報を取得します。'
            '位置情報は、周辺の地域名・ランドマーク・店舗情報を取得するためにのみ使用され、'
            'デバイス上にのみ保存されます。位置情報は第三者に送信されることはありません。',
          ),
          const SizedBox(height: 16),
          const Text(
            '2. データの保存',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '案内履歴は、ユーザーのデバイス上のローカルデータベースに保存されます。'
            'これらのデータは、ユーザーがアプリを削除するまで保持されます。',
          ),
          const SizedBox(height: 16),
          const Text(
            '3. 外部APIの使用',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '本アプリは、Google Places APIおよびGoogle Geocoding APIを使用して'
            '周辺情報を取得します。これらのAPIへのリクエストには位置情報が含まれますが、'
            'Googleのプライバシーポリシーに従って取り扱われます。',
          ),
          const SizedBox(height: 16),
          const Text(
            '4. お問い合わせ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'プライバシーに関するご質問やご意見がございましたら、'
            'アプリの開発者までお問い合わせください。',
          ),
        ],
      ),
    );
  }
}

class _TermsOfServiceTab extends StatelessWidget {
  const _TermsOfServiceTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '利用規約',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '最終更新日: 2026年2月21日',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            '1. サービスの利用',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '本アプリは、お散歩中の案内サービスを提供します。'
            'ユーザーは、本アプリを利用することで、本規約に同意したものとみなされます。',
          ),
          const SizedBox(height: 16),
          const Text(
            '2. 免責事項',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '本アプリは、案内情報の正確性を保証するものではありません。'
            '案内内容は参考情報としてご利用ください。'
            '本アプリの利用により生じた損害について、開発者は一切の責任を負いません。',
          ),
          const SizedBox(height: 16),
          const Text(
            '3. 位置情報の利用',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '本アプリは、位置情報の取得にユーザーの許可が必要です。'
            '位置情報の許可がない場合、アプリの機能は正常に動作しません。',
          ),
          const SizedBox(height: 16),
          const Text(
            '4. 規約の変更',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '開発者は、事前の通知なく本規約を変更することができます。'
            '変更後の規約は、アプリ内で通知されます。',
          ),
        ],
      ),
    );
  }
}
