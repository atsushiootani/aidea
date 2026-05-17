---
title: GitHub Actions で xcodebuild CI を構築する
description: PR ごとに GitHub Actions が xcodebuild を実行してビルド・テストを検証し、失敗時のマージをブロックする設計判断
status: 保留
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-17
---

# GitHub Actions で xcodebuild CI を構築する

**日付**: 2026-05-02

## 背景

Aidea は macOS ネイティブ Swift/SwiftUI アプリであり、コンパイルエラーや型エラーが PR に混入しやすい。手動でビルド確認する運用は見落としが起きやすく、main ブランチを壊すリスクがある。

## 決定

PR ごとに GitHub Actions (`macos-15` ランナー) が `xcodebuild build` と `xcodebuild test` (UI テスト除く) を自動実行する。

- ビルド失敗またはテスト失敗の場合、GitHub の branch protection `required status check` によりマージをブロックする
- CI 失敗を検知したら `/aidea.ci-fix` スキルが最大 3 回まで自動修正を試みる
- 3 回で解決しない場合はスキルが停止しユーザに報告する

## 理由

- **GitHub Actions は無料枠で macOS ランナーが使える**: 追加インフラ不要
- **xcodebuild は Apple 公式**: サードパーティ CI ラッパー不要
- **branch protection でマージブロック**: コードレビューと同様に main 保護ができる
- **3 回ルール**: 同じエラーを延々リトライするより早期に人間へエスカレーションする方がコスト効率が高い

## 考慮した代替案

| 案 | 却下理由 |
|---|---|
| Xcode Cloud | Apple Developer Program ($99/年) が必要 |
| Bitrise / CircleCI | 追加サービス契約が必要。外部依存を最小化する方針に反する |
| ローカル CI のみ (pre-push hook) | push 前にのみ検証されるため PR 後の変更に無力 |

## 影響

- `.github/workflows/ci.yml` を新設する
- `.claude/commands/aidea.ci-fix.md` スキルを新設する
- GitHub リポジトリ設定で `main` ブランチの branch protection を手動設定する必要がある (ワークフローファイルでは設定不可)

---

## 保留 (2026-05-17)

GitHub Actions の **macOS ランナーの月間無料枠を使い切った** ため、CI 実行が継続できなくなった。本決定 (採用) を一旦**保留** (Status: 保留) とし、以下を実施した:

- `.github/workflows/ci.yml` を削除 (PR で CI が走らないようにする)
- `docs/specs/aspects/ci-cd.md` を削除 (実装が無くなった spec を残さない)
- `docs/specs/aspects/README.md` から CI 関連の記述を削除
- `.claude/commands/aidea.ci-fix.md` / `aidea.ci-watch.md` スキルは残置 (CI 復活時に再利用するため)

### 再開条件 / 次回アクション

- 月初リセットで無料枠が回復したタイミングで再評価する
- 継続的に超過するようなら以下を検討:
  - Xcode Cloud ($99/年の Apple Developer Program 加入)
  - セルフホスト macOS ランナー (手元 Mac を runner として登録)
  - pre-push hook によるローカル CI のみ運用 (PR 後の変更は無検証になるトレードオフを許容)

### トレードオフ

- **当面 PR のビルド/テスト検証が自動で走らない**: マージ前にビルド通るかは人間が手で確認するか、`/aidea.ci-fix` の代わりに手動 `xcodebuild` を回す運用に戻る
- **branch protection の required status check が dangling**: GitHub Settings 側で `build` job 必須設定が残っていると PR がマージ不可になるので、合わせて外す必要がある (リポジトリ Settings の手動操作)
