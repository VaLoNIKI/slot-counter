# 小役カウンター（SlotCounter）

ロック画面のライブアクティビティからパチスロの小役（ベル・チェリー・スイカ・チャンス目）を数える iPhone アプリです。
Mac を使わず、GitHub Actions でビルドし、Windows の Sideloadly で無料 Apple ID 署名してインストールします。

## 機能

- アプリで「開始」を押すと、ロック画面（と Dynamic Island）に小役カウンターを表示
- ロック画面のボタンをタップすると、Face ID なし・アプリを開かずに +1（`LiveActivityIntent`）
- 「取消」ボタンで直前の 1 カウントを取り消し（履歴は最大 1000 件）
- アプリで「停止」を押すとライブアクティビティを終了
- 総G数（手入力）と各小役の確率（1/xx）をアプリ画面に表示。総G数を入れるとロック画面にも確率を表示
- カウントは端末に保存されます。ライブアクティビティは iOS の仕様で最長 8 時間で終わるので、終わったら（または終わる前に）アプリで「再開始」を押せば続きから表示されます
- アプリ画面の小役行をタップしても +1 できます。リセットボタンあり（確認つき）

## 構成

```
project.yml                 XcodeGen 定義（.xcodeproj はコミットしない）
App/                        アプリ本体（画面、ライブアクティビティの開始/停止）
Widget/                     ウィジェット拡張（ロック画面 / Dynamic Island の表示）
Shared/                     両ターゲット共通（小役定義、保存、AppIntent）
.github/workflows/build.yml 署名なし .ipa を作るワークフロー
```

- バンドルID：アプリ `com.valoniki.slotcounter`、ウィジェット拡張 `com.valoniki.slotcounter.widget`
  - 変える場合は `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` 2 か所（拡張はアプリIDの配下にすること）
- App Groups は使っていません。ロック画面ボタンの Intent はアプリのプロセスで動くため、保存は普通の `UserDefaults` で共有できます
- Intent には `authenticationPolicy = .alwaysAllowed` を設定済み（ロック中でも実行可）

## ビルド（GitHub Actions）

`main` を含むどのブランチでも push するたびに macOS ランナーでビルドされます。手動実行は Actions タブの「Build unsigned IPA」→「Run workflow」。

1. GitHub のリポジトリ → **Actions** → 最新の成功した実行を開く
2. 下の **Artifacts** の `SlotCounter-ipa` をダウンロード
3. ダウンロードした zip を展開すると `SlotCounter.ipa` が出てくる（これを Sideloadly に渡す）

gh を使う場合（Windows の PowerShell で）:

```bash
gh run download --repo VaLoNIKI/slot-counter --name SlotCounter-ipa --dir .\ipa
```

`.\ipa\SlotCounter.ipa` に保存されます（gh は zip を自動で展開します）。

## Sideloadly でのインストール手順（Windows）

### 事前準備（PC）

1. **iTunes と iCloud を Apple 公式サイトから入手したデスクトップ版で入れる**（Microsoft Store 版だと Sideloadly が iPhone を認識しないことがあります）
2. [Sideloadly](https://sideloadly.io/) をインストール
3. iPhone を USB ケーブルで接続し、iPhone 側で「このコンピュータを信頼」→パスコード入力

### インストール

1. Sideloadly を起動
2. 左上の IPA アイコンに `SlotCounter.ipa` をドラッグ＆ドロップ
3. **iDevice** に自分の iPhone が出ていることを確認
4. **Apple account** に無料 Apple ID のメールアドレスを入力
5. **Start** を押し、求められたら Apple ID のパスワード（2 段階認証コード）を入力
   - パスワードは Sideloadly が Apple に送るためのもので、このリポジトリには関係ありません
6. 「Done.」と表示されれば完了

うまくいかないとき：
- 「バンドルIDが使えない」系のエラー：`project.yml` のバンドルIDを他と被らない名前に変えて push し、新しい ipa で再実行
- 「App ID の上限」系のエラー：無料 Apple ID は 7 日間に作れる App ID が 10 個までです（このアプリは本体＋ウィジェットで 2 個使います）。日を置くか、同じバンドルIDで入れ直してください

## iPhone 側で必要な設定

1. **デベロッパモードをオン**（iOS 16 以降で必須）
   - 一度 Sideloadly でインストールすると、**設定 > プライバシーとセキュリティ > デベロッパモード** が現れます
   - オン → 再起動 → 再起動後のダイアログで「オンにする」→パスコード入力
2. **開発元を信頼する**
   - **設定 > 一般 > VPN とデバイス管理** → 自分の Apple ID のデベロッパ App → 「信頼」
   - これをしないとアプリを開いたときに「信頼されていないデベロッパ」と出て起動できません
3. **ライブアクティビティを許可**
   - **設定 > 小役カウンター > ライブアクティビティ** をオン
   - **設定 > Face ID とパスコード > ロック中にアクセスを許可** の「ライブアクティビティ」がオンであること（オフだとロック中に表示・操作できません）

## 使い方

1. アプリを開き、必要なら総G数を入力
2. 「開始」→ ロック画面にカウンターが出る
3. ロック画面のボタン（ベル / チェリー / スイカ / チャンス目）をタップで +1、「取消」で直前を取り消し
4. 総G数を更新したいときはアプリで入力し直す（ロック画面の確率も更新されます）
5. 終わったら「停止」

## 注意（無料 Apple ID の制限）

- **7 日で署名が切れます**。切れるとアプリが起動しなくなるので、7 日以内に Sideloadly で同じ ipa を入れ直してください（カウントはアプリを削除しなければ残ります）
- 無料 Apple ID で同時にインストールできるサイドロードアプリは 3 個までです
- Sideloadly を常駐させ、PC と iPhone を同じ Wi-Fi に置いておくと自動更新（Auto Refresh）も使えます
