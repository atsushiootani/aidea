---
description: PR を作成する。main ブランチ作業中ならブランチを切り、未コミット確認と docs ヘルスチェック実施確認を行い、作成後に PR URL を表示する。
---

# aidea.pr

Aidea プロジェクトでプルリクエストを作成するための手順。以下を **1つずつ順番に** 実施する。

## やること

### 1. 未コミット変更の確認

`git status` を実行し、ワーキングツリーに未コミットの変更 (modified / untracked) があるかを確認する。

- **変更がある場合**: ユーザに「未コミットの変更がありますが、どうしますか？」と確認し、指示 (コミット / スタッシュ / 破棄 / そのまま続行) を仰ぐ。ユーザの返答が得られるまで次のステップに進まない。
- **変更がない場合**: 次のステップへ進む。

### 2. ブランチ確認とブランチ切り

現在のブランチを `git rev-parse --abbrev-ref HEAD` で確認する。

- **現在のブランチが `main` の場合**:
  - 作業内容に適したブランチ名をユーザに確認してから、新しいブランチを `git checkout -b <branch-name>` で切る
  - ブランチ名の慣例: `feature/<summary>` / `fix/<summary>` / `fix/issue-<number>-<summary>` / `docs/<summary>` / `chore/<summary>`
- **それ以外のブランチの場合**: そのまま続行する。

### 3. docs ヘルスチェック実施確認

ユーザに `/aidea.docs-healthcheck` を実施済みか確認する。

- **未実施の場合**: 実施するかどうかユーザに確認し、実施するなら `/aidea.docs-healthcheck` を先に走らせる。スキップする判断が返ってきたら次に進む。
- **実施済みの場合**: 次のステップへ進む。

### 4. PR 作成

1. `git log main..HEAD --oneline` でコミット一覧を確認し、`git diff main...HEAD` で全変更を把握する
2. ブランチにアップストリームが無ければ `git push -u origin <branch-name>` で push する
3. `gh pr create` でプルリクエストを作成する
   - タイトルは 70 文字以内で簡潔に。ブランチ種別に合わせて `fix:` / `feat:` / `docs:` / `chore:` / `refactor:` などの Conventional Commits 風プレフィックスを付ける
   - Issue と紐付く場合は本文に `Closes #<番号>` を記載する
   - 本文には以下を含める:
     - `## Summary` — 変更点を箇条書きで要約
     - `## Test plan` — 動作確認用チェックリスト
     - 末尾に `🤖 Generated with [Claude Code](https://claude.com/claude-code)` を追記
   - HEREDOC で body を渡してフォーマットを保つ

### 5. PR URL の表示

`gh pr create` の返り値の URL をそのままユーザに表示する。併せて PR 番号とタイトルを伝える。

## 注意

- `--no-verify` や `-i` (interactive) オプションは使わない
- force push は行わない
- `git add -A` / `git add .` は避け、対象ファイルを明示する
- 本人の明示指示が無い限りマージはしない (PR 作成までで止める)
