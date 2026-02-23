# Walk Walk

現在地を一定間隔で取得し、周辺の地域名・主要ランドマーク・店舗情報を取得して音声で案内する**お散歩支援アプリ**です。

---

## 目次

- [セットアップ](#セットアップ)
- [機能](#機能)
- [設定項目](#設定項目)
- [設計](#設計)
- [テスト方針](#テスト方針)
- [技術スタック](#技術スタック)
- [必要な権限](#必要な権限)
- [注意事項・トラブルシューティング](#注意事項トラブルシューティング)

---

## セットアップ

### 1. 依存関係のインストール

```bash
flutter pub get
```

### 2. 環境変数の設定

`.env.example` をコピーして `.env` を作成し、Google API キーを設定します。

```bash
cp .env.example .env
```

`.env` の例：

```
GOOGLE_PLACES_API_KEY=your_api_key_here
GOOGLE_GEOCODING_API_KEY=your_api_key_here
```

`pubspec.yaml` の `assets` に `.env` が含まれているため、アプリから読み込まれます。

### 3. データベースコード生成（Drift）

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. アプリの実行

```bash
flutter run
```

**サポートプラットフォーム**: Android / iOS（推奨）。Linux デスクトップもビルド可能です。**Web（Chrome）は未対応**です（Drift/SQLite が dart:ffi を使用するため）。実機・エミュレータを接続するか、`flutter run -d android` / `flutter run -d ios` で対象を指定してください。

**Linux デスクトップ**で実行する場合は、事前に以下をインストールしてください。

```bash
sudo apt install cmake ninja-build g++ pkg-config libgtk-3-dev lld
```

- `CXX=clang++` を使う場合は `clang` も必要です。未導入の場合は `unset CXX` または `CXX=g++ flutter run` を推奨します。

---

## 機能

| 機能 | 説明 |
|------|------|
| **位置情報の定期取得** | 設定した間隔（分刻み）で現在地を取得 |
| **逆ジオコーディング** | 座標から地域名を取得（Google Geocoding API） |
| **POI 検索** | Google Places API (New) の searchNearby で周辺のランドマーク・店舗を検索 |
| **音声案内** | TTS による案内文の読み上げ |
| **バックグラウンド動作** | アプリを閉じても案内を継続（設定で ON/OFF） |
| **案内履歴** | 案内メッセージの保存・一覧表示 |
| **案内抑制** | クールダウン・距離閾値・重複抑制で案内頻度を調整 |

---

## 設定項目

| 項目 | 範囲・単位 | 説明 |
|------|------------|------|
| 位置情報取得間隔 | 10〜30 **分**（分刻み） | 現在地を取得する間隔 |
| 検索半径 | 100〜2000 **m** | 周辺検索の半径 |
| 案内クールダウン | 10〜120 秒 | 同一案内の最小間隔 |
| 距離閾値 | 10〜100 m | 前回案内地点からの最小移動距離 |
| 履歴保持期間 | 24〜720 時間 | 案内履歴の保持期間 |
| TTS 速度 | 0.0〜1.0 | 読み上げ速度 |
| TTS 言語 | 日本語 / 英語 | 読み上げ言語 |
| バックグラウンド動作 | ON / OFF | アプリ非表示時の案内継続 |

---

## 設計

### アーキテクチャ方針

**クリーンアーキテクチャ**を採用し、**Riverpod** で状態を管理しています。  
ドメインは外部に依存せず、UI・インフラはドメインのインターフェースに依存します。

```
presentation → application → domain
                  ↑
            infrastructure
```

### レイヤー構成

| レイヤー | パス | 役割 |
|----------|------|------|
| **domain** | `lib/domain/` | モデル定義とサービスインターフェース（GeocodingProvider, PlacesProvider, GuidanceFormatter 等） |
| **application** | `lib/application/` | ユースケース（WalkSessionUseCase, FetchNearbyInfoUseCase）と Riverpod による状態管理 |
| **infrastructure** | `lib/infrastructure/` | 位置・TTS・通知・DB・外部 API の実装 |
| **presentation** | `lib/presentation/` | 画面（Home, Settings, Policy）と UI のみ |

### 主要コンポーネント

- **WalkSessionUseCase**: お散歩の開始/停止、案内実行のトリガー
- **FetchNearbyInfoUseCase**: 現在地から逆ジオコーディング + POI 検索 → `NearbyContext` を生成
- **GuidanceThrottle**: クールダウン・距離・重複を考慮して「案内するか」を判定
- **GuidanceFormatter**: `NearbyContext` と設定から案内文を生成
- **BackgroundWorker**: バックグラウンドでの位置監視と定期案内
- **CacheRepository**: ジオコーディング・Places のキャッシュ（Drift）
- **GuidanceHistoryRepository**: 案内メッセージの永続化（Drift）

### データフロー（1 回の案内）

1. 現在地取得（LocationService）
2. ジオハッシュでキャッシュ確認 → 未ヒットなら Geocoding API / Places API 呼び出し → キャッシュ保存
3. `NearbyContext`（地域名・ランドマーク・店舗）を組み立て
4. GuidanceThrottle で「案内するか」判定
5. GuidanceFormatter で案内文を生成
6. TTS で読み上げ
7. GuidanceHistoryRepository に保存

### ドメインモデル（代表）

- **GeoPoint**: 緯度・経度
- **LocationSample**: 位置 + タイムスタンプ・精度・高度
- **NearbyContext**: 地域名、ランドマーク一覧、店舗一覧
- **GuidanceMessage**: 案内 1 件（ID・文言・日時・座標・タグ等）
- **AppSettings**: 上記「設定項目」の永続化用モデル

### ストレージ設計

- **SharedPreferences**: アプリ設定（AppSettings）の保存
- **Drift (SQLite)**:
  - ジオコーディングキャッシュ（キー・地域名・有効期限）
  - Places キャッシュ（キー・JSON・有効期限）
  - 案内メッセージ履歴（ID・文言・日時・座標・地域名・タグ JSON）

---

## テスト方針

**TDD（テスト駆動開発）** に則り、実装変更の前にテストで変更意図を表現することを推奨します。

### テストの実行

```bash
flutter test
```

通常のユニット・ウィジェットテスト（CI 想定）は上記のままです。統合テストを含めない場合は `flutter test --exclude-tags=integration` でも同じです。

### 統合テスト（実 API）

実 API（Google Geocoding API / Google Places API）を呼ぶ統合テストは、次のコマンドで実行します。

```bash
flutter test --tags=integration
```

- **実行前に** `.env` に `GOOGLE_PLACES_API_KEY`（および必要なら `GOOGLE_GEOCODING_API_KEY`）を設定してください。
- キーが未設定または空の場合、統合テストは **スキップ** され、失敗にはなりません。CI で API キーを渡さなければ統合テストはスキップされ、既存の `flutter test` はそのまま利用できます。
- 統合テストは SQLite のメモリ DB を使用するため、実行環境に **libsqlite3**（例: Linux では `libsqlite3-dev`）が入っている必要があります。入っていない場合は「Failed to load dynamic library 'libsqlite3.so'」などのエラーになります。
- 実 API を叩くため、実行頻度が高いとクォータに触れる可能性があります。主にローカル確認用としてください。

### 方針

- **設計書通りの UI・挙動**をテストで検証する（例: HomeScreen / SettingsScreen の表示・操作、FetchNearbyInfoUseCase のキャッシュ・API 呼び出し）。
- **外部依存**（API・DB・位置情報・TTS など）はモック・スタブで置き換え、テスト環境で再現可能にする。
- **TDD**: 実装変更前には、変更意図を満たすテストを先に追加・更新する。そのテストが（現状では失敗してよいので）用意できてから実装に着手する。

---

## 技術スタック

| 用途 | パッケージ |
|------|------------|
| 状態管理 | flutter_riverpod ^2.4.9 |
| 位置情報 | geolocator ^10.1.0, geolocator_linux ^0.2.0 |
| 音声合成 | flutter_tts ^4.0.0 |
| 通知 | flutter_local_notifications ^16.3.0 |
| 設定保存 | shared_preferences ^2.2.2 |
| ローカル DB | drift ^2.14.0, sqlite3_flutter_libs, path_provider, path |
| HTTP | http ^1.1.0, dio ^5.4.0 |
| ジオハッシュ | dart_geohash ^2.1.0 |
| 環境変数 | flutter_dotenv ^5.1.0 |
| ログ | logger ^2.0.2 |
| その他 | uuid, intl |

- Flutter SDK: 3.0+
- Dart SDK: >=3.0.0 <4.0.0

---

## 必要な権限

### Android

- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`: 位置情報
- `FOREGROUND_SERVICE`: バックグラウンド用フォアグラウンドサービス
- `POST_NOTIFICATIONS`: 通知表示
- `INTERNET`: API 通信

### iOS

- `NSLocationWhenInUseUsageDescription`: 使用中の位置情報
- `NSLocationAlwaysAndWhenInUseUsageDescription`: 常時位置情報（バックグラウンド用）
- `UIBackgroundModes: location`: バックグラウンド位置更新

### Linux（デスクトップ）

- 位置情報は geolocator_linux に依存。未実装の場合は「位置情報はこの端末では利用できません」と表示され、実機・エミュレータでの利用を案内します。

---

## 注意事項・トラブルシューティング

1. **API 制限**  
   Google Places / Geocoding API にはリクエスト制限があります。キャッシュで同一条件の再取得を抑えています。

2. **バッテリー**  
   位置情報取得間隔を 10〜30 分の範囲で大きくすると、バッテリー負荷を抑えられます。

3. **プライバシー**  
   位置情報の利用目的はアプリ内のプライバシーポリシーで明示してください。

4. **実機テスト**  
   バックグラウンド・位置・通知は実機での動作確認を推奨します。

5. **デスクトップ（Linux）**  
   - 位置情報が使えない場合は上記のメッセージが表示されます。  
   - 通知は `LinuxInitializationSettings` / `LinuxNotificationDetails` を指定して初期化しています。

6. **設定画面でクラッシュする場合**  
   古い設定（例: 5 分間隔・50 m 半径）が保存されていると、新しい範囲（10〜30 分・100〜2000 m）とずれることがあります。アプリは読み込み時に範囲内へ正規化するため、最新版で再起動すれば解消されます。

7. **ビルドエラー**  
   - `dart run build_runner build --delete-conflicting-outputs` を実行していないと Drift の生成コードがなくて失敗します。  
   - Linux でリンカエラー（`ld.lld` 等）が出る場合は `lld` のインストール（`sudo apt install lld`）を試してください。

8. **周辺案内が空（「特に目立った施設はありません」になる）ときの確認手順**  
   - **ログの確認**: デバッグ実行時、コンソールに次のようなログが出ます（本アプリは Places API (New) の searchNearby を使用）。  
     - `Places API (New) POST ... type=store`（`type=restaurant` / `cafe` / `park` も同様）: 各 type でリクエストしているか。  
     - `Places API (New) response type=... results=N`: 各 type で何件返っているか。  
     - `Places API (New) error: code=... message=...`: API キー無効・制限・未有効化など。  
   - エラー時はレスポンスの `error` オブジェクト（code / message）がログに出力され、例外が投げられます。  
   - **キャッシュの影響**: 以前の検索結果がキャッシュされていると、同じ地点・半径では API が呼ばれず「POIキャッシュから取得」と出ます。設定画面（DEV 時のみ表示）の「キャッシュ・案内履歴を削除」でキャッシュを消してから、お散歩を停止して再開すると再検索されます。  
   - **テスト位置**: 設定でテスト用位置（東京駅周辺など）を指定している場合、その座標で store / restaurant / cafe / park の 4 種を検索し、取得した POI を案内に使います。検索半径（例: 2000 m）を大きくするとヒットしやすくなります。

9. **Places API で REQUEST_DENIED（API key is not authorized）が出る場合**  
   ログに `status=REQUEST_DENIED` や「This API key is not authorized to use this service or API」と出る場合は、プロジェクトで Places API が有効でないか、API キーの制限で Places API が許可されていません。  
   **対処手順**:  
   1. [Google Cloud Console](https://console.cloud.google.com/) で対象プロジェクトを選択する。  
   2. **「API とサービス」→「ライブラリ」** を開く。  
   3. **「Places API」** を検索し、未有効なら **「有効にする」** をクリックする。  
   4. 逆ジオコーディングでも使うため、未有効なら **「Geocoding API」** も有効にする。  
   5. **「API とサービス」→「認証情報」** で使用している API キーを開く。  
   6. そのキーに **「API の制限」** が設定されている場合、**「キーを制限」** の一覧に **「Places API」** および **「Geocoding API」** が含まれているか確認する。含まれていなければ追加するか、一時的に「制限なし」で動作確認する。  
   設定変更後、API キーを再読み込みする必要はなく、次のリクエストから有効になります。
