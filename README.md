# Walk Walk アプリ

現在地を一定間隔で取得し、周辺の地域名・主要ランドマーク・店舗情報を取得して音声で案内するお散歩支援アプリです。

## セットアップ

### 1. 依存関係のインストール

```bash
flutter pub get
```

### 2. 環境変数の設定

`.env.example`をコピーして`.env`ファイルを作成し、Google APIキーを設定してください：

```bash
cp .env.example .env
```

`.env`ファイルに以下を設定：
```
GOOGLE_PLACES_API_KEY=your_api_key_here
GOOGLE_GEOCODING_API_KEY=your_api_key_here
```

### 3. データベースコード生成

Driftデータベースのコードを生成する必要があります：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. アプリの実行

```bash
flutter run
```

## 機能

- **位置情報の定期取得**: ユーザー設定可能な間隔で現在地を取得
- **逆ジオコーディング**: 座標から地域名を取得
- **POI検索**: Google Places APIを使用して周辺のランドマーク・店舗を検索
- **音声案内**: TTS（Text-to-Speech）による音声案内
- **バックグラウンド動作**: アプリを閉じても案内を続ける（設定で有効/無効可能）
- **案内履歴**: 過去の案内履歴を保存・表示
- **案内抑制**: クールダウン・距離閾値・重複抑制による適切な案内頻度の制御

## 設定項目

- 位置情報取得間隔（10-300秒）
- 検索半径（50-1000メートル）
- 案内クールダウン（10-120秒）
- 距離閾値（10-100メートル）
- 履歴保持期間（24-720時間）
- TTS速度（0.0-1.0）
- TTS言語（日本語/英語）
- バックグラウンド動作の有効/無効

## 必要な権限

### Android
- `ACCESS_FINE_LOCATION`: 正確な位置情報の取得
- `ACCESS_COARSE_LOCATION`: おおよその位置情報の取得
- `FOREGROUND_SERVICE`: バックグラウンド動作のためのフォアグラウンドサービス
- `POST_NOTIFICATIONS`: 通知の表示

### iOS
- `NSLocationWhenInUseUsageDescription`: 使用中の位置情報アクセス
- `NSLocationAlwaysAndWhenInUseUsageDescription`: 常時位置情報アクセス（バックグラウンド用）
- `UIBackgroundModes: location`: バックグラウンドでの位置情報更新

## アーキテクチャ

クリーンアーキテクチャ + Riverpod（状態管理）を使用しています。

- **domain**: ドメインモデルとサービスインターフェース
- **application**: ユースケースと状態管理
- **infrastructure**: 外部API、データベース、サービス実装
- **presentation**: UI実装

## 技術スタック

- Flutter 3.0+
- flutter_riverpod 2.4.9
- geolocator 10.1.0
- flutter_tts 4.0.0
- drift 2.14.0
- shared_preferences 2.2.2
- dio 5.4.0
- geohash 2.0.1
- flutter_dotenv 5.1.0
- logger 2.0.2

## 注意事項

1. **API制限**: Google Places APIにはリクエスト制限があるため、キャッシュを活用しています
2. **バッテリー消費**: 位置情報の取得間隔を適切に設定し、バッテリー消費を最小化してください
3. **プライバシー**: 位置情報の取り扱いについて、プライバシーポリシーを明確に記載してください
4. **実機テスト**: 特にバックグラウンド処理は実機でのテストが必須です
