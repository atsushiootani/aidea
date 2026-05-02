---
description: 直前に作成した PR をマージし、ローカル main を最新化してマージ済みブランチを削除する。mergeable でなければユーザに確認する。
---

# aidea.merge

Aidea プロジェクトでプルリクエストをマージし、ローカル環境を最新化するための手順。以下を **1つずつ順番に** 実施する。

## やること

### 1. 対象 PR の特定

マージ対象の PR を特定する。

- **会話の中で直前に作成した PR の番号が明らかな場合**: その PR を対象とする
- **対象が不明確な場合**: `gh pr list --author @me --state open` で自分のオープン PR 一覧を表示し、ユーザにどの PR をマージするか確認する。ユーザの返答が得られるまで次のステップに進まない

### 2. PR の approve 可能性を確認

対象 PR について `gh pr view <番号> --json state,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision` で状態を確認する。

以下の条件を **すべて満たす** ことを確認する:

- `state` が `OPEN`
- `mergeable` が `MERGEABLE`
- `mergeStateStatus` が `CLEAN` もしくは `UNSTABLE` (要ユーザ確認)
- `reviewDecision` が `APPROVED` もしくは 不要 (Aidea は個人プロジェクトなので基本的に不要だが、Required レビューが設定されていれば従う)

#### CI/CD ステータスの確認 (必須)

`statusCheckRollup` および `gh pr checks <番号>` の出力を確認し、CI/CD の各チェック結果を必ずチェックする。

- **エラーがある場合** (`conclusion` が `FAILURE` / `CANCELLED` / `TIMED_OUT` / `ACTION_REQUIRED` / `STARTUP_FAILURE` のいずれか): **マージは行わない**。以下を整理してユーザに報告し、指示を仰ぐ:
  - 失敗したワークフロー / チェック名と conclusion
  - `gh pr checks <番号>` の関連行 (URL 含む)
  - 失敗ログを掘りたい場合は `gh run view <run-id> --log-failed` の実行を提案
  - ユーザから「失敗を承知でマージする」「修正して再 push する」「中止する」のいずれかの明示指示を受けるまで次のステップに進まない
- **進行中の場合** (`PENDING` / `IN_PROGRESS` / `QUEUED`): 完了を待つか、待たずに進めるかをユーザに確認する。返答が得られるまで次に進まない
- **すべて成功** (`SUCCESS` / `NEUTRAL` / `SKIPPED`) の場合のみ次のステップへ進む

**その他の条件を満たさない場合**: 何が原因でマージできないかをユーザに伝え、「このままマージしてよいか / 中止するか」を確認する。ユーザの返答が得られるまで次に進まない。

### 3. PR のマージ

`gh pr merge <番号> --merge` でマージする (merge commit 方式)。

- squash / rebase を使いたい場合はユーザ指示に従う
- `--delete-branch` は **付けない** (ローカルブランチ削除を自分で行うため、リモートブランチもセットで消したい場合のみユーザに確認して付ける)

マージ完了後に `gh pr view <番号> --json state,mergedAt,mergedBy` で `state: MERGED` を確認する。

### 4. ローカル main の更新

ローカル環境を最新 main に合わせる。

1. `git status` でワーキングツリーの状態を確認する
2. **未コミット変更がある場合**: ユーザに「未コミットの変更がありますが、どうしますか？ (コミット / スタッシュ / 破棄 / 中止)」と確認し、指示を仰ぐ。確認を得るまで次に進まない
3. `git checkout main` で main に切り替える
4. `git pull origin main` で最新を取り込む
5. pull 時にコンフリクトや他の差分で失敗した場合は、**自動解決せず** にユーザに状況を報告し、対応方針を問い合わせる

### 5. マージ済みローカルブランチの削除

マージ元のローカルブランチを削除する。

1. 対象ブランチ名を特定する (PR の `headRefName` もしくは直前まで作業していたブランチ)
2. 現在のブランチが main であることを確認する
3. `git branch -d <branch-name>` で削除する
   - `-D` (強制削除) は使わない。`-d` が失敗した場合はユーザに理由を報告し判断を仰ぐ
4. 削除が成功したら `git status` と `git log --oneline -5` で最終状態をユーザに報告する

## 注意

- force push や `git reset --hard` は使わない
- リモートブランチの削除は明示指示があった場合のみ行う
- マージコミットや squash の戦略はデフォルトで `--merge`。他を使うときはユーザに確認する
