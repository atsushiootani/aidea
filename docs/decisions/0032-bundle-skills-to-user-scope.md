---
title: "0032: aidea.* スキルをアプリ同梱し初回起動時にユーザスコープへ自動配置する"
description: aidea.* の Claude Code スキルをアプリ Bundle に同梱し、初回起動時に ~/.claude/skills/ (ユーザスコープ) へ冪等コピーして自動登録する決定。プラグイン/マーケットプレイス方式は採らず、既存 BackchannelSetup と同じ「同梱→コピー」パターンに揃える
status: 採用
derived_from:
  - docs/decisions/0022-companion-instructions-as-files.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-15
---

# 0032: aidea.* スキルをアプリ同梱し初回起動時にユーザスコープへ自動配置する

**日付**: 2026-06-15

## 背景

Aidea は `aidea.docs-healthcheck` / `aidea.round-table` / `aidea.docs-graph` などの Claude Code スキルを前提に運用している (docs/specs/skills/ や スケジューラのルーティンが `/aidea.docs-healthcheck` 等を呼ぶ)。

しかしこれらのスキルは `.claude/commands/` に置かれており、[ADR 0026](./0026-use-git-info-exclude-instead-of-gitignore.md) 系の方針で `.claude/` は **ローカル個人設定として git 管理外** (gitignore 相当)。そのため:

- スキルの実体が git に乗っておらず、**消えると復元が手作業**になる (実際 `aidea.docs-healthcheck` は gitignore 統合時に追跡から外れ、ローカルからも失われていた)
- 別マシンや別ユーザが Aidea を使い始めても、**aidea.\* スキルが自動では入らない**

ユーザの要望は「**Aidea をインストールしたら (＝初めてどこかのディレクトリで Aidea を開いたら)、aidea.\* スキルがユーザスコープに登録される**」状態にすること。

## 問題

Claude Code のスキル配布手段は大きく 2 系統ある。

1. **プラグイン + マーケットプレイス** (公式の本命): git repo に `.claude-plugin/marketplace.json` を置き、`/plugin install` または `settings.json` の `extraKnownMarketplaces` + `enabledPlugins` で登録する。スキルは `~/.claude/plugins/<plugin>@<marketplace>/skills/` に入り、`/<plugin>:<skill>` と **コロン名前空間**で呼ぶ。
2. **`~/.claude/skills/` への直接配置** (アプリ同梱型): アプリが同梱スキルを `~/.claude/skills/<name>/SKILL.md` へコピーする。登録ステップ不要で**自動 discovery**、file-watcher で即反映。呼び出しは `/<name>` (ドット名も維持可能)。

Aidea は macOS ネイティブアプリでアプリ自身が起動ライフサイクルを握っており、かつ既に同種の「Bundle テンプレ → ユーザ領域へコピー」を `BackchannelSetup` で実装済み (`.aidea/claude/*.md` を冪等コピー＋ユーザ編集保護＋後発機能の backfill)。どちらの配布方式を採るかを決める。

## 決定

**方式 2 (アプリ同梱 → 初回起動時に `~/.claude/skills/` へ管理コピー)** を採用する。

1. **同梱**: `aidea.*` の実体を **リポジトリ内**に置き (gitignore されない場所)、ビルド時にアプリ Bundle のリソースへ含める。これが SSoT になる。
2. **配置先 (4 分類)**: **user / project** スコープ × **skill / command** タイプの 4 通りを配置先として扱う。一般化された配布物は既定で **user スコープ** (`~/.claude/skills/` `~/.claude/commands/`)、リポジトリ固有情報は **project スコープ** (`<projectRoot>/.claude/skills|commands/`) に置く。どこで開いても使えること優先で、汎用部は user スコープに寄せる。
3. **配布用の一般化**: 配布物はリポジトリ非依存に**一般化**し、特定リポジトリ固有の情報 (対象パス・規約・キャスト等) は**別ファイルに分離**して本体から参照する。
4. **タイミング**: アプリ起動 (リポジトリオープン) 時に `BackchannelSetup` と同じ経路で `SkillSetup.setup(projectRoot:)` を呼ぶ。
5. **冪等＋更新戦略**: 各配置先ルートの管理マニフェスト (`<root>/.aidea-managed.json`) に配布済み資産の version / hash を記録する。
   - 不在 → コピー
   - 存在かつ「前回配布 hash と一致 (＝ユーザ未編集)」→ 新版で上書き更新
   - 存在かつユーザ編集済み → **上書きしない** (ユーザ編集を保護)。ログのみ残す
6. **命名**: `aidea.` プレフィックスを維持し、`/aidea.docs-healthcheck` のドット呼称をそのまま使う (ユーザの既存運用・ルーティン・docs リンクを壊さない)。
7. **App Sandbox**: Aidea は App Sandbox 無効 ([境界ルール](../../CLAUDE.md)) のため `~/.claude/` への書き込みが可能。本決定はその前提に乗る。

機構の詳細は [docs/specs/skills/skill-bootstrap.md](../specs/skills/skill-bootstrap.md) を参照。

## 理由

1. **既存パターンとの一貫性**: `BackchannelSetup` と同じ「Bundle → ユーザ領域へ冪等コピー」。新しい配布インフラ (git repo ホスティング・marketplace.json・バージョン公開フロー) を持ち込まない。
2. **登録ステップ不要**: ユーザスコープ `~/.claude/skills/` は Claude Code が自動 discovery する。`/plugin install` のような明示操作が要らず「開いたら使える」を満たす。
3. **命名の維持**: 方式 1 だと `/aidea:docs-healthcheck` (コロン) に変わり、既存の docs リンク・スケジューラのルーティンプロンプト・ユーザの手癖をすべて書き換える必要がある。方式 2 はドット名を維持できる。
4. **オフライン/閉域でも動く**: 配布が外部 git やネットワークに依存しない。
5. **git 管理に戻せる**: 実体をリポジトリ内に置くため、消失リスク (今回の `docs-healthcheck` 喪失) が構造的に解消する。

## 結果

- aidea.* スキルの SSoT がリポジトリ内に移り、git で版管理される。
- 初回起動でユーザスコープに自動登録され、2 回目以降はマニフェスト照合で「未編集なら更新／編集済みなら保護」。
- スキルの呼称・docs リンク・ルーティンは現状のまま温存される。
- (トレードオフ) マーケットプレイスのような**横展開での発見性・他者への公開**は得られない。Aidea 利用者に閉じた配布になる。将来 OSS 公開等で広く配りたくなったら、方式 1 (marketplace) への移行を別 ADR で検討する。

## 代替案

- **方式 1: プラグイン + マーケットプレイス**。標準的で発見性が高いが、外部 git repo ホスティング・`marketplace.json`/`plugin.json` 維持・`/plugin install` UX・コロン名前空間への改称が必要。Aidea 同梱の手軽さに対しオーバースペック。将来の OSS 公開時に再検討。
- **シンボリックリンク**: Bundle 内スキルを `~/.claude/skills/` へ symlink。アプリ更新が即反映される利点はあるが、アプリ削除/移動でリンク切れ・ユーザ編集ができない等の脆さがあり不採用。
- **project スコープ (`.claude/skills/`) へ配置**: リポジトリごとに配置が要り「どこで開いても使える」を満たせないため不採用。
