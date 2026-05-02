---
title: CI/CD (継続的インテグレーション)
description: GitHub Actions による xcodebuild CI パイプラインの仕様、エラー検出・マージブロック・自動修正スキルを横断的に定義する
derived_from:
  - docs/decisions/0025-github-actions-ci.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-05-02
---

# CI/CD (継続的インテグレーション)

PR ごとに xcodebuild でビルドを検証し、エラーがあればマージをブロックする仕組みの仕様。

---

## パイプライン概要

```
PR 作成 / push
  └─ GitHub Actions: ci.yml
       └─ xcodebuild build + test
            ├─ 成功 → マージ可
            └─ 失敗 → マージブロック (branch protection required status check)
                  └─ /aidea.ci-fix スキルで自動修正 (最大 3 回)
```

---

## GitHub Actions ワークフロー (`.github/workflows/ci.yml`)

| 項目 | 値 |
|---|---|
| トリガー | `pull_request` (opened / synchronize / reopened) |
| ランナー | `macos-15` |
| ジョブ | `build` — xcodebuild build; `test` — xcodebuild test (UI テスト除く) |
| コード署名 | `CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` (CI 環境では署名しない) |
| プロジェクト | `Aidea/Aidea.xcodeproj` スキーム `Aidea` |
| デスティネーション | `platform=macOS,arch=arm64` |

### マージブロック設定

GitHub リポジトリの **Settings → Branches → Branch protection rules** で `main` ブランチに対して以下を設定する (ワークフローファイルでは設定不可):

- [x] **Require status checks to pass before merging**
- [x] Required status check: `build` (ci.yml のジョブ名)

---

## CI エラー自動修正スキル (`/aidea.ci-fix`)

`.claude/commands/aidea.ci-fix.md` として定義。

### 手動起動

1. 現在のブランチの最新 PR を特定する
2. CI チェックランの状態を取得し、失敗しているジョブのログを取得する
3. ビルドエラー・テストエラーを解析して Swift コードを修正する
4. 修正をコミット・プッシュして CI の再実行を待つ
5. 最大 3 回リトライし、それでも失敗すればエラー内容をユーザに報告して停止する

### Claude routine での利用

PR activity (CI 失敗イベント) を `<github-webhook-activity>` 経由で受信したとき、自動的に `/aidea.ci-fix` を呼び出す。3 回試みて解決しない場合はルーティンを停止してエラーを報告する。

---

## 設計ポリシー

- **署名レス CI**: CI 環境では `CODE_SIGNING_REQUIRED=NO` で署名をスキップする。配布ビルドとは別フローとして扱う
- **UI テスト除外**: CI ではヘッドレス実行が困難な UI テスト (`AideaUITests`) を `-skip-testing:AideaUITests` で除外する
- **3 回ルール**: 自動修正は最大 3 回まで。それ以上は人間の判断が必要と見なして停止・報告する
