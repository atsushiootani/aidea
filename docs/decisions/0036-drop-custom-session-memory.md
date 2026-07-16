---
title: "0036: 独自のセッション間記憶機構を廃止し Claude ネイティブのセッションに委譲する"
description: コンパニオンが .aidea/backchannels/<N>/context.txt に作業コンテキストを手書きで書き出す独自の記憶機構 (context.md / context.txt) を廃止し、セッション間の記憶は Claude ネイティブのセッション (会話ログ .jsonl + --resume) と CLAUDE.md / 自動メモリに一元化する
status: 提案
derived_from:
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/README.md
  - docs/specs/aspects/persistence.md
  - docs/specs/sessions/claude.md
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-27
---

# 0036: 独自のセッション間記憶機構を廃止し Claude ネイティブのセッションに委譲する

**日付**: 2026-06-27 / **issue**: #209, #229

## 背景

#175 (closes #111) で「コンパニオンのセッション間記憶保持機能」を導入した。仕組みは:

- Bundle リソース `.aidea/claude/context.md` を初回コピーし、`instructions.md` から参照させる
- Claude がセッション終了時に作業コンテキスト (現在のタスク・決定事項・次のステップ) を
  `.aidea/backchannels/<companion-index>/context.txt` へ**手書きで要約・上書き**する
- 次回セッション開始時に Claude がそれを読み返して記憶を引き継ぐ

仕様は backchannels/context.md (本 ADR により廃止・削除済み)。

その後 issue #209 (セッションの記憶管理) と #229 (context.md は不要で claude 自体のコンテキストを
参照すればよいのでは) で、「この独自機構は Claude ネイティブのメモリ/コンテキスト機能と
二重管理になっていないか」が提起された。

### 調査で判明した事実

1. **進行中の作業状態は Claude のセッションそのものに既に入っている。**
   Aidea の Claude 起動シーケンス ([sessions/claude.md#自動起動シーケンス](../specs/sessions/claude.md)) の
   経路 B (tmux 再 attach) では、claude TUI が生きたまま再接続されるため、
   **warm 再起動では会話 (=作業記憶) がそのまま継続する**。context.txt は同じ情報の手書き写しでしかない。

2. **会話ログは常にディスクに残る。**
   各セッションの会話は `~/.claude/projects/<encoded-projectRoot>/<session-id>.jsonl` に保存され、
   `claude --resume <session-id>` / `--continue` で会話コンテキストごと復元できる
   (公式 docs: sessions / memory)。

3. **Claude ネイティブの自動メモリは "git リポジトリ単位"** で、per-session / per-companion には
   分離されない。よって「context.txt を自動メモリで置き換える」素朴な案は、
   同一プロジェクトで複数 Companion を並行起動する Aidea には**そのままは適用できない**。
   恒久的な知見・好みは元々 `CLAUDE.md` (user / project) でカバーされている。

つまり context.txt が担っていた 2 つの役割は、いずれも独自機構を持たずに賄える:

| context.txt の役割 | ネイティブの担い手 |
|---|---|
| 進行中タスクの作業状態 | Claude セッション本体 (warm=tmux 継続 / cold=会話ログ + `--resume`) |
| 恒久的な知見・好み | `CLAUDE.md` (user / project) + ネイティブ自動メモリ |

## 判断

**`context.md` / `context.txt` による独自のセッション間記憶機構を廃止する。**
セッション間の記憶は Claude ネイティブのセッション (会話ログ `.jsonl` + `--resume`) と
`CLAUDE.md` / 自動メモリに一元化し、Aidea は独自の記憶レイヤーを持たない。

### 撤去対象

| 種別 | 対象 | 操作 |
|---|---|---|
| Bundle リソース | `Aidea/Aidea/Resources/Backchannels/context.md` | 削除 |
| Bundle リソース | `companion-instructions.md` / `companion-agent.md` の `context.md` 参照行 | 削除 |
| コード | `BackchannelSetup` の `knownFeatures` から `"context"` を除外、コピー対象から外す | 変更 |
| 仕様書 | `docs/specs/backchannels/context.md` | 削除 |
| 仕様書 | `backchannel.md` / `backchannels/README.md` / `aspects/persistence.md` の context 記述 | 削除 |

### 残置 (消さないもの)

- 既存ユーザの `.aidea/backchannels/<N>/context.txt` は [ADR 0024](./0024-backchannel-per-companion-archive.md)
  に従い Aidea からは削除しない。参照されなくなるだけで、ユーザが任意に手で消す。
- 既にコピー済みの `.aidea/claude/context.md` も同様に残置 (Aidea は上書き/削除しない)。

## 理由

1. **二重管理の解消**: 作業記憶は Claude セッション本体に既にあり、context.txt はその手書き写し。
   要約のための余分なターン・トークンを消費し、書き忘れ・古い内容で誤誘導するリスクもあった。
2. **ネイティブへの一本化**: 恒久知見は `CLAUDE.md`、会話の継続は `--resume`、という
   Claude が公式に持つ仕組みに揃えることで、機能更新に追従でき保守対象が減る。
3. **per-companion 分離を壊さない**: 自動メモリは repo 単位で分離できないが、
   会話ログ/`--resume` は session-id 単位なので、同一 cwd で複数 Companion を動かしても
   記憶が混ざらない (独自機構なしで per-companion が成立する)。

## やらないこと (スコープ外)

- **cold start の自動記憶復元**。tmux が消えた cold start (経路 A) では従来どおり新規会話になる。
  前回の続きが必要な場合はユーザが `claude --resume` で手動復元する (会話ログのパスは別途 `ccpath` 等で取得可)。
  cold start でも自動で `--resume` させる案 (Aidea が Companion ごとに `--session-id` を採番・永続化し
  起動時に resume する) は、起動シーケンス改修 ([ADR 0008](./0008-no-claude-autostart.md) /
  [ADR 0022](./0022-companion-instructions-as-files.md) に波及) を伴うため**別 ADR で扱う**。
- ネイティブ自動メモリの per-companion 分離 (repo 単位仕様のため不可)。

## トレードオフ

- **cold start で進行中タスクの記憶が自動継続しなくなる** (warm は従来どおり継続)。
  手動 `--resume` で復元可能だが、ワンクリックではない。許容コストとして受け入れる。
- **既存環境では `instructions.md` が「ユーザ編集保護」で上書きされない** ([ADR 0022](./0022-companion-instructions-as-files.md))。
  そのため既存の `instructions.md` / `companion-agent.md` は `context.md` を参照し続け、
  既にコピー済みの `.aidea/claude/context.md` を読み込もうとする。新規環境はクリーンだが、
  既存環境は (a) ユーザが手で参照行を消す、または (b) 既存ファイルを再生成する、で解消する。
  本 ADR では Aidea からの強制上書きは行わない (編集保護を優先)。
