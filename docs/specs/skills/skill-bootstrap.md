---
title: スキル・ブートストラップ (aidea.* の自動配置)
description: アプリ Bundle に同梱した aidea.* の skill / command を、起動時に user / project スコープの ~/.claude(skills|commands) へ冪等コピーして自動登録する機構の仕様。4 分類の配置先・管理マニフェストによる更新判定・ユーザ編集保護・配布用一般化 (固有情報の別ファイル分離) を含む
derived_from:
  - docs/decisions/0032-bundle-skills-to-user-scope.md
syncs_with:
  - docs/specs/skills/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-15
---

# スキル・ブートストラップ (aidea.* の自動配置)

`aidea.*` の Claude Code 資産 (skill / command) を、アプリ起動時に Claude Code が読む所定ディレクトリへ自動配置する機構。
方式の決定背景は [ADR 0032](../../decisions/0032-bundle-skills-to-user-scope.md) を参照。
既存の同種機構 (`.aidea/claude/` への配置) は [backchannel.md](../backchannels/backchannel.md) を参照。

## 目的

- Aidea を**初めて開いたら** `aidea.*` が `/aidea.<name>` として使える状態にする (登録操作不要)。
- 資産の実体を**リポジトリ内に持ち** (gitignore 喪失リスクの解消)、ビルドで Bundle に同梱する。
- アプリ更新時、**ユーザが編集していないものだけ**新版へ更新し、編集済みは保護する。
- 配布物は**リポジトリ非依存に一般化**し、特定リポジトリ固有の情報は別ファイルに分離する。

## 4 分類の配置 (scope × type)

Claude Code は **user / project** の 2 スコープ、**skill / command** の 2 タイプを読む。本機構はこの 4 通りを配置先として扱う。

| scope | type | 配置先 | 呼称 | 配置タイミング |
|---|---|---|---|---|
| user | skill | `~/.claude/skills/aidea.<name>/SKILL.md` | `/aidea.<name>` | 起動時 (1 回・グローバル) |
| user | command | `~/.claude/commands/aidea.<name>.md` | `/aidea.<name>` | 起動時 (1 回・グローバル) |
| project | skill | `<projectRoot>/.claude/skills/aidea.<name>/SKILL.md` | `/aidea.<name>` | リポジトリオープン毎 |
| project | command | `<projectRoot>/.claude/commands/aidea.<name>.md` | `/aidea.<name>` | リポジトリオープン毎 |

- **user スコープ**: どのディレクトリで開いても効く。**一般化された配布物**の既定の置き場。
- **project スコープ**: リポジトリごとに異なる**固有情報**の置き場 (後述の分離先)。`<projectRoot>` を要するため `BackchannelSetup` 同様に projectRoot を受け取る。
- どの分類でも `aidea.` プレフィックスで他スキルとの衝突を避け、ドット呼称 `/aidea.<name>` を維持する (ADR 0032 の理由 3)。

## Bundle ソースの構成 (SSoT)

リポジトリ内 `Aidea/ClaudeAssets/` に 4 分類でディレクトリを分け、**フォルダ参照 (blue folder)** として
アプリ Bundle に同梱する。フォルダ参照なので**配置先と同じディレクトリ構造がそのまま保持される**
(通常のリソースはフラット化されるため、構造を保つにはフォルダ参照が必須)。

```
Aidea/ClaudeAssets/                       → Bundle: Aidea.app/Contents/Resources/ClaudeAssets/
├── user/
│   ├── skills/    <name>/SKILL.md (+ 付随ファイル)
│   └── commands/  <name>.md
└── project/
    ├── skills/    <name>/SKILL.md (+ 付随ファイル)
    │   ├── aidea.docs-healthcheck/SKILL.md
    │   └── aidea.round-table/SKILL.md
    └── commands/  <name>.md
```

配置は **`scope/type` カテゴリごとのミラーコピー**: `ClaudeAssets/<scope>/<type>/` 配下の各ファイルを、
対応する配置先ルート (前掲の表) へ同じ相対パスでコピーするだけ。索引ファイルや名前変換は持たない。
空カテゴリは `.gitkeep` で git 追跡し、配置時は `.` 始まりのファイルを除外する。

### リポジトリ固有情報はバンドルに含めない

バンドルは**全リポジトリ共通に配れる一般部 (`SKILL.md`) だけ**を運ぶ。特定リポジトリ固有の固有部
(`specifics.md` / `cast.md` 等) を同梱すると、その内容が**全リポジトリへ漏れてしまう**ため含めない。
固有部は当該リポジトリの project skill ディレクトリ (`<repo>/.claude/skills/<name>/`) に直接置く。
`.claude/` は gitignore 対象なので**コミットせずローカルに保持**する (各リポジトリで各自が編集・管理する personal な内容のため。削除はしない)。
配布された一般部 `SKILL.md` は、同ディレクトリに固有部があればそれを参照し、無ければ汎用動作にフォールバックする。

## 配布用の一般化 (固有情報の分離)

配布する skill / command は**リポジトリ非依存の一般ロジックのみ**を本体 (`SKILL.md` / `<name>.md`) に書く。
特定リポジトリ固有の情報 (対象パス・規約・キャスト等) は**別ファイルに分離**し、本体からはそれを参照する。

- **一般部 (本体)**: 既定で **user スコープ**へ配布 (どのリポでも効く)。
- **固有部 (別ファイル)**: **project スコープ**へ配布、またはリポジトリ内の既存ドキュメントを参照する。本体は「固有部があればそれに従う」設計にする。

### 既存 2 コマンドの移行 (実施済み)

現状 `.claude/commands/` にある 2 つを、この枠組みへ移す。両者とも **project スコープの skill** とし、一般部 (`SKILL.md`) と固有部 (兄弟ファイル) を**同じ skill ディレクトリ内**に分離する。

- **一般部 `SKILL.md`** は repo 非依存に一般化し、**バンドルに同梱**して配布する (`ClaudeAssets/project/skills/<name>/SKILL.md`)。
- **固有部** (`specifics.md` / `cast.md`) は Aidea 固有なので**バンドルに含めず**、この repo の `.claude/skills/<name>/` に直接置く。`.claude/` は gitignore 対象のため**コミットせずローカル保持**する (削除はしない)。

| 資産 (すべて project / skill) | 一般部 `SKILL.md` (バンドル同梱・git 追跡) | 固有部 (`.claude/skills/` にローカル保持・gitignore) |
|---|---|---|
| `aidea.docs-healthcheck` | docs ヘルスチェックの**汎用手順** (矛盾・未定義参照・stale・frontmatter・抜け漏れの一般カテゴリと報告) | `specifics.md`: 対象ディレクトリと各領域の判定基準 SSoT。Aidea では `docs/decisions/` `docs/specs/` ・各 README の「ヘルスチェック」節・[LAYOUT.md](../../LAYOUT.md) ・実装詳細禁止 grep |
| `aidea.round-table` | 多視点ディスカッション進行の**汎用ロジック** (議題化 → ラウンド → 統合・ハンドオフ規約) | `cast.md`: 登場キャラ・index・ハンドオフ順。Aidea の 5 キャラ (main/idea/review/red/black) |

→ 配布された `SKILL.md` は、配置先で同ディレクトリの固有部ファイルを相対参照する (`./specifics.md` / `./cast.md`)。
他リポジトリでは固有部を置けばそのまま適合し、無ければ `SKILL.md` が汎用動作にフォールバックする。
純汎用スキルを将来 user スコープへ配布する余地も残す (本移行は repo 固有のため project スコープ)。

## タイミング

アプリ起動 (リポジトリオープン) 時、`BackchannelSetup.setup(projectRoot:)` と同じ流れで `SkillSetup.setup(projectRoot:)` を一度実行する。

- user スコープ分: 冪等なので毎回実行しても結果は一意 (実質グローバルに 1 回)。
- project スコープ分: その `projectRoot` の `.claude/` に配置する。

## 更新判定 (管理マニフェスト)

各配置先ルートに管理マニフェスト `<root>/.aidea-managed.json` を置き、「Aidea が最後にどの内容で配布したか」を記録する。

- 例: `~/.claude/skills/.aidea-managed.json` / `~/.claude/commands/.aidea-managed.json` / `<projectRoot>/.claude/skills/.aidea-managed.json` …

```jsonc
{
  "version": 1,
  "assets": {
    "aidea.docs-healthcheck": { "shippedHash": "<sha256 of bundled body>" },
    "aidea.round-table":      { "shippedHash": "<sha256>" }
  }
}
```

各資産について、起動時に以下を判定する。

| 現状 | 判定 | 動作 |
|---|---|---|
| 不在 | 新規 | Bundle からコピーし `shippedHash` を記録 |
| 存在 & 現ファイル hash == `shippedHash` | 未編集 | Bundle が新しければ上書き更新し `shippedHash` を更新 |
| 存在 & 現ファイル hash != `shippedHash` | ユーザ編集済み | **上書きしない** (保護)。`NSLog` で警告のみ |
| 存在 & マニフェスト未記載 | 由来不明 | 安全側に倒し上書きしない (ユーザ自作の同名資産を尊重) |

- hash は本体ファイル (`SKILL.md` / `<name>.md`) の sha256。付随ファイルを持つ skill は将来ディレクトリ全体の hash に拡張余地を残す (現行は本体単体)。
- 「未編集なら更新」により、アプリ更新で不具合修正・新資産追加がユーザに自動で行き渡る (`BackchannelSetup` の backfill と同じ思想)。

## 境界

### Always
- 配置先は 4 分類 (user/project × skill/command) のいずれか。一般化された配布物は既定で user スコープ。
- 資産の実体は**リポジトリ内**を SSoT とし Bundle へ同梱する。
- 配布物は一般化し、リポジトリ固有情報は別ファイルへ分離する。
- ユーザが編集した資産 (hash 不一致) は**上書きしない**。
- 配置は冪等。複数リポジトリ/複数回起動でも結果が一意。

### Never
- 既存のユーザ編集資産や、マニフェスト未記載の同名資産を破壊しない。
- 資産のアンインストール (配置先からの削除) は本機構では行わない (掃除は対象外)。
- プラグイン/マーケットプレイス機構 (`~/.claude/plugins/`・`settings.json` の `enabledPlugins`) には関与しない (ADR 0032 で方式 2 を採用)。
