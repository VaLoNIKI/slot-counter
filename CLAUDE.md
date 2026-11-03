# CLAUDE.md

このリポジトリは**公開リポジトリ**です。作業するときは次のルールを必ず守ってください。

## commit / push 前の確認（毎回必須）

commit と push の前に、差分（未 push のコミットすべてを含む）に次のものが入っていないか確認し、**結果をユーザーに報告してから push する**こと。

- 秘密鍵・証明書・プロファイル：`.p12` `.p8` `.cer` `.pem` `.mobileprovision`、`-----BEGIN ... PRIVATE KEY-----` など
- トークン、パスワード、API キー（GitHub トークン `ghp_` / `gho_` / `github_pat_`、App Store Connect の API キー、`.env` の中身など）
- 個人のメールアドレス（コミットの作者・コミッターを含む）。使ってよいのは GitHub の noreply アドレス（`136291953+VaLoNIKI@users.noreply.github.com`）だけ

確認の例：

```bash
git diff --cached --stat
git log origin/main..HEAD --format='%an <%ae> | %cn <%ce>'
git diff origin/main --name-only | grep -Ei '\.(p12|p8|cer|pem|mobileprovision)$|\.env'
git diff origin/main | grep -nEi 'BEGIN .*PRIVATE KEY|ghp_|gho_|github_pat_|password|passwd|secret|api[_-]?key|token|@[a-z0-9.-]+\.[a-z]{2,}'
```

push 後は、GitHub Actions の `Secret scan`（gitleaks）が成功していることも確認する。

## 秘密情報の扱い

- Apple ID、パスワード、App Store Connect の API キー、証明書などを**コードやワークフローに直書きしない**。必要なら GitHub Secrets（`${{ secrets.NAME }}`）を使う
- 秘密情報を含むファイルは `.gitignore` 済み（`*.p12` `*.p8` `*.cer` `*.mobileprovision` `*.pem` `.env`）。`git add -f` で無理に追加しない

## 外から見える範囲が変わる操作

次の操作は、**必ず事前にユーザーに確認**してから行う。

- リポジトリの公開／非公開の切り替え
- リポジトリ名の変更、移管、削除
- コラボレーター、Deploy key、Webhook、GitHub Pages、Releases の追加・変更
- Actions の Artifacts 以外の場所（Release など）への成果物の公開
