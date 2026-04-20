---
description: 引数の番号または URL から GitHub issue を特定し、実装系なら specs 作成から、不具合系なら仕様バグ/実装バグを切り分けて作業を進める起点にする。
---

# aidea.issue.start

Aidea プロジェクトで GitHub issue の作業起点を作るための手順。以下を **1つずつ順番に** 実施する。

引数 `$ARGUMENTS` には issue 番号 (例: `72` / `#72`) または URL (例: `https://github.com/<owner>/<repo>/issues/72`) が渡される。

## やること

### 1. 対象 issue の特定

引数 `$ARGUMENTS` を解釈し、対象 issue を確定する。

- **数字のみ / `#` 付き番号**: そのまま `<番号>` として扱う
- **URL**: 末尾パス `/issues/<番号>` から `<番号>` を抽出する
- **引数が空**: `gh issue list --state open --assignee @me` を実行してユーザに対象 issue を確認する。返答を得るまで次に進まない

### 2. issue 内容の把握

`gh issue view <番号> --json number,title,body,labels,state,url,comments` で詳細を取得する。

1. `state` が `OPEN` でない場合 (CLOSED 等) は、続行してよいかユーザに確認する
2. タイトル・本文・コメントを読み、要点を 3〜5 行でユーザに要約提示する
3. 種別を判定する:
   - `labels` に `bug` / `defect` / 類似ラベルがあれば **不具合系**
   - `labels` に `enhancement` / `feature` / 類似ラベルがあれば **実装系**
   - ラベルが無い、または両方の性質を含む場合は本文から推測し、**迷ったらユーザに確認する**

### 3. ブランチ確認とブランチ切り

現在のブランチを `git rev-parse --abbrev-ref HEAD` で確認する。

- **`main` の場合**: 以下の命名でブランチ名を提案し、ユーザに確認してから `git checkout -b <branch-name>` で切る
  - 実装系: `feature/issue-<番号>-<summary>`
  - 不具合系: `fix/issue-<番号>-<summary>`
- **それ以外のブランチの場合**: そのブランチで続行してよいかユーザに確認する

未コミット変更がある場合は、`/aidea.pr` と同じ要領で (コミット / スタッシュ / 破棄 / そのまま続行) をユーザに確認する。

### 4a. 実装系 (feature / enhancement) の場合

**specs の作成・更新から始める** (Aidea 規約: 実装前に specs を書いて一度確認してから実装に進む)。

1. issue の内容から、どの specs カテゴリに属するかを判定する
   - 参照: [../../docs/LAYOUT.md](../../docs/LAYOUT.md)
   - 主な候補: `docs/specs/sessions/` / `docs/specs/tools/` / `docs/specs/companions/` / `docs/specs/frontchannels/` / `docs/specs/aspects/` / `docs/specs/window/`
2. 関連する既存 specs を読み込み、影響範囲を洗い出す
3. 新規 specs が必要なら `docs/LAYOUT.md` のフロントマター規約に従ってドラフトを作成する
4. 既存 specs の更新が必要なら該当箇所を修正する
5. **specs を書き終えたらユーザに一度レビューを依頼する**。承認が得られるまで実装には進まない
6. 承認後にコード実装に進む

### 4b. 不具合系 (bug) の場合

**仕様バグか実装バグかを区別してから作業を始める。**

1. issue に書かれている「あるべき挙動」と「実際の挙動」を整理する
2. 関連する specs (`docs/specs/` 以下) を読み、仕様上どうあるべきかを確認する
3. 判定基準:
   - **仕様バグ**: specs に記載がない、specs 同士が矛盾している、または specs の記述そのものが望ましくない
   - **実装バグ**: specs は正しく、実装がそれに従っていない
4. 判定結果と根拠をユーザに伝え、迷う場合はユーザに確認する

判定後:

- **仕様バグの場合**:
  1. specs を修正する
  2. 変更後に `/aidea.docs-healthcheck` を走らせるかユーザに提案する
  3. 必要に応じて specs に合わせてコードを修正する

- **実装バグの場合**:
  1. 該当コードを Grep / Read で特定する
  2. コードを修正する
  3. 修正の経緯・判断が specs に書かれていない場合、必要に応じて specs または `docs/decisions/` (ADR) に書き戻す

### 5. 完了後

1. 変更内容を要約してユーザに報告する
2. この段階では **勝手にコミット・PR 作成はしない**。ユーザから明示指示があれば `/aidea.pr` に引き継ぐ

## 注意

- `gh issue view` は `--json` で必要フィールドのみ取得する (長文出力を避けるため)
- issue と紐付く PR を将来作るときは、PR 本文に `Closes #<番号>` を入れる (`/aidea.pr` 側で実施)
- specs と実装の両方を変更するときは、先に specs を合意してから実装する (Aidea 規約)
- ユーザの指示なしに `git commit` / `git push` はしない
