---
title: コンパニオン
description: ヘッダの 9 体アイコン・index で識別されるコンパニオン設定とストアの仕様・workspace.json v8 経由の永続化・起動フロー・instructions.md/agent.md 外部化
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/decisions/0029-companion-as-agent-definition.md
syncs_with:
  - docs/specs/companions/agent-definition.md
  - docs/specs/companions/recommend-mode.md
  - docs/specs/companions/speech-history.md
  - docs/specs/aspects/persistence.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/companion-roster.md
  - docs/specs/backchannels/voicevox.md
  - docs/specs/sessions/claude.md
  - docs/specs/tools/claude.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# コンパニオン

> ヘッダに常時並ぶ **9 体固定** のアイコン。1 体が 1 つの Claude セッションに紐付き、
> 起動・フォーカス・レコメンド送信の入口になる。

[../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) が規定する「Aidea → Claude」通信の起点にあたる UI 概念。
送信メカニズム自体は frontchannel.md、レコメンド UI は [recommend-mode.md](./recommend-mode.md) を参照。

---

## 概要

- ヘッダに **9 体のコンパニオンアイコンが index 0〜8 で常に並ぶ** (個数は固定で増減できない)
- 各アイコンは同梱の 9 枚のプリセット画像に対応
- 起動済み (Claude セッションと bind 済み) のアイコンは彩度 1.0、未起動は 0.3 でグレーアウト
- アクティブタブがそのコンパニオンの Claude セッションならアクセントカラーで枠が付く

### タップ操作

| 対象 | 動作 |
|---|---|
| アイコン (起動済み) | 紐付く Claude セッションをアクティブ化 |
| アイコン (未起動) | コンパニオンの設定で Claude セッションを起動し bind する |
| 名前ラベル | 編集シート (sheet) を開いて設定を編集 (name / icon / 「指示書を開く」ボタン) |

---

## データモデル

### コンパニオン設定

1 体のコンパニオン設定 + 起動状態を表すデータ構造。

| 項目 | 意味 |
|---|---|
| index (0〜8) | コンパニオン識別子。ヘッダ表示順とも一致 |
| 名前 | タブ・ラベルに出る表示名 |
| アイコン名 | アイコン画像の識別名 (`Companions/companion-N` または SF Symbols 名) |
| 紐付きセッション ID | 紐付いた Claude セッションの識別子。なければ未起動 |

紐付きセッション ID は **設定** (名前 / アイコン) と一体で保存される。これは workspace.json が「現在のワークスペースのスナップショット」であり、設定とランタイム状態を一体で保存する設計に揃えている (sessions セクションも同様の構成)。

#### initialPrompt の外部ファイル化 (v8 以降)

v7 まではコンパニオン設定内の `initialPrompt` 文字列として保持していたが、v8 で削除。各コンパニオンの初期指示は `<projectRoot>/.aidea/claude/companions/<index>/instructions.md` に外部化されている (詳細は [ADR 0022](../../decisions/0022-companion-instructions-as-files.md))。

Aidea が起動時に PTY へ送る文字列は Companion index から派生するパターン:

- **`agent.md` が存在する場合**: `.aidea/claude/companions/<index>/agent.md を読んでエージェントとして振る舞ってね`
- **`agent.md` が存在しない場合 (フォールバック)**: `.aidea/claude/companions/<index>/instructions.md を読んで従ってね`

この文字列の生成・ファイル存在確認・パス解決は、コンパニオン指示書ヘルパに集約される。
エージェント定義の詳細は [agent-definition.md](./agent-definition.md) を参照。

### アイコンプリセット

アイコン画像の静的プリセット。各コンパニオンに対し以下 4 種のバリアントをアプリ同梱の画像リソースとして持つ。

| サフィックス | 用途 | 画像名例 |
|---|---|---|
| (なし) | 通常表情 (normal) | `companion-1.jpg` |
| `-small` | 小サイズ版 (リスト等) | `companion-1-small.jpg` |
| `-smile` | 笑顔表情 (読み上げ中) | `companion-1-smile.jpg` |
| `-thinking` | 考え中表情 (Claude 実行中) | `companion-1-thinking.jpg` |

`-smile` / `-thinking` は issue #45 で追加された表情セット。読み上げ中と実行中の表示切替に使う (詳細は後述の「表情・状態表示」節)。

ただし **コンパニオンのデフォルト名 / icon の値そのもの** は Bundle 同梱の `default-workspace.json` の `companions[]` が SSoT。アイコンプリセットは同梱アイコンリソースの対応表のみを担う。デフォルトの instructions.md 本文は Bundle 同梱のテンプレ (1 ファイルを 9 個に複製) が SSoT。

---

## ストア

9 個固定のコンパニオン配列をインメモリで保持するコンポーネント。永続化はワークスペーススナップショット管理経由で `.aidea/workspace.json` に書き出される (詳細は [../aspects/persistence.md](../aspects/persistence.md))。

### 状態

| 状態 | 意味 |
|---|---|
| コンパニオン配列 | **必ず 9 要素 (index 0〜8)**。空にしたり追加・削除はしない |

紐付け情報は各コンパニオン設定の紐付きセッション ID に統合済み。Companion→Session の別の対応表は持たない。

### 主要な操作

| 操作 | 挙動 |
|---|---|
| 設定更新 | 指定 index のコンパニオン設定を更新 (名前 / アイコン / 紐付きセッション ID を差し替え)。名前を変更する経路 (主に編集シートの OK 確定) では呼び出し側が直後にコンパニオン名簿の書き出しを行い、`.aidea/claude/aidea.md` のコンパニオン名簿セクションを更新する ([companion-roster.md](../backchannels/companion-roster.md)) |
| bind | コンパニオンと Claude セッションを紐付ける (指定 index の紐付きセッション ID をセット) |
| unbind | 指定 index の紐付けを解除する |
| セッション単位の unbind | 該当セッション ID を持つコンパニオンの紐付けを解除する (タブを閉じたとき用) |
| 起動済み判定 | 指定 index に紐付きセッション ID があるかを返す |
| 取得 | 指定 index のコンパニオン設定を返す (必ず存在) |
| 名前の逆引き | セッション ID から該当コンパニオン名を逆引きする (タブ表示で使用) |

コンパニオンの追加・削除・動的生成の操作は **持たない** (9 個固定で動的増減しないため)。

### 永続化

コンパニオン配列は `workspace.json` v8 の `companions` フィールドに保存される (`initialPrompt` フィールドは v8 で削除済み)。詳細スキーマは [../aspects/persistence.md](../aspects/persistence.md) を参照。

旧スキーマからのマイグレーション:
- v6 → v7: UUID 識別 + `companionBindings` 別配列を icon 名 → index 逆算で統合
- v7 → v8: `companions[].initialPrompt` を削除 + 各文字列を `.aidea/claude/companions/<index>/instructions.md` に書き出し (ファイル不在時のみ。詳細は [ADR 0022](../../decisions/0022-companion-instructions-as-files.md))

---

## View 構成

| 役割 | 責務 |
|---|---|
| コンパニオン列 (ヘッダ本体) | ヘッダに 9 体並べる。アイコンタップで起動/フォーカス、ラベルタップで編集 sheet を開く。レコメンドモード中は選択コンパニオンの下にレコメンド吹き出しを表示 |
| 編集シート | 名前・アイコンを編集する sheet。「指示書を開く」ボタンで `.aidea/claude/companions/<index>/instructions.md` を Preview セッションとして開く (markdown view + 編集モード) |
| レコメンド吹き出し | レコメンドプロンプト一覧を縦に並べ、選択中をアクセントカラーでハイライトする吹き出し |

---

## 起動フロー (Claude セッション未起動)

1. ユーザが未起動アイコン (index N) をタップする
2. index N のコンパニオン設定をストアから取得する (必ず存在)
3. Claude Tool の新しいインスタンス番号を採番する
4. Claude セッションを生成する
5. 起動時指示コマンドをセッションにセットする
   ( = `agent.md` が存在すれば「agent.md を読んでエージェントとして振る舞ってね」、
   なければ「instructions.md を読んで従ってね」のフォールバック。
   ターミナル起動後に自動送信される → [tools/claude.md](../tools/claude.md))
6. コンパニオン N と生成したセッションを bind する
7. アクティブ pane の末尾にタブ追加しアクティブ化する

`instructions.md` が不在のまま起動した場合の挙動は初回セットアップ処理の責務 (新規プロジェクト初回セットアップ時にコピー)。詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

---

## 起動フロー (スナップショット復元時)

Aidea 起動時、`workspace.json` から Claude タブが復元されるケースの挙動:

1. アプリ起動時にワークスペーススナップショット (`workspace.json`) を読み込む
   - 旧版なら自動マイグレーション (v6 → v7 で UUID → index 化、bindings 統合)
   - `workspace.json` 不在なら Bundle 同梱の `default-workspace.json` を使う
2. スナップショット適用処理が同期的に以下を実行する:
   - レイアウトツリー復元 (タブ構成のみ、セッション実体は未生成)
   - スナップショットの companions (9 要素) をストアにセット
   - スナップショットの recommends をレコメンド設定にセット
3. 同じ適用処理内で、セッションに紐付いたコンパニオンへ起動時指示コマンドを再注入する:
   - コンパニオン配列を走査し、紐付きセッション ID を持つ index について
   - 対応する Claude セッション状態を生成する (PTY / 端末 View は引き続き遅延生成)
   - 起動時指示コマンドをセットする ( = `agent.md` があれば「agent.md を読んでエージェントとして振る舞ってね」、なければ instructions.md フォールバック)
   - Companion index もセットする (Scene 識別子 `claude:<index>` 解決用)
4. ユーザがタブをアクティブ化 → 端末 View 生成 → 自動起動シーケンスで起動時指示コマンドが送信される

この再注入がないと、復元された Claude セッションは起動時指示コマンドを持たないまま
`claude` CLI だけが起動し、初期指示が送られない (Issue #69 の挙動)。

---

## 表情・状態表示 (issue #45)

Companion アイコンは 4 つの状態を持ち、ベース画像 (normal / smile / thinking) と
SF Symbol オーバーレイの組み合わせで表現する。

### 状態と表示

| 状態 | 発火条件 | ベース画像 | オーバーレイ | アイコン暗転 |
|---|---|---|---|---|
| **未起動** | セッション未紐付け | `companion-N-small` (thumbnail) | なし | 彩度 0.3 / 不透明度 0.5 |
| **アイドル** | セッション起動済み・実行中でない・読み上げ中でない | `companion-N-small` (thumbnail) | なし | なし |
| **実行中** | Claude セッションが実行中 (isBusy) | `companion-N-thinking` | `ellipsis.bubble` (濃いグレー) | なし |
| **読み上げ中** | 音声キューが当該 Companion (index N) を読み上げ中 | `companion-N-smile` | `heart.fill` (pink) | なし |

### 優先順位

同時に複数の条件が成立した場合、**読み上げ中 > 実行中 > アイドル > 未起動** の順で上位を採用する。
通常のフローでは「プロンプト送信 → 実行中 → (要約 speech 書き出しで) 読み上げ中」と遷移するため、実行中と読み上げ中が長時間同時成立することはないが、両方成立した瞬間は読み上げ中を優先する。

### オーバーレイの詳細

- **位置**: アイコン右上隅 (コーナーバッジ風)
- **サイズ**: アイコン幅の約 1/3 (60x60 アイコンに対して 18pt)
- **色**:
  - `heart.fill`: pink
  - `ellipsis.bubble`: 濃いグレー (white 0.25 の固定色。dark/light mode に依らず同じ視認性を得るため、システムの標準文字色に従わない)
- **背景**: SF Symbol の後ろに半透明の白角丸 (角丸 4pt、白の不透明度 0.6) を敷く。アイコン画像のコントラストに関係なく記号が沈まないよう視認性を確保するため
- **描画順**: ベース画像の上にオーバーレイする (枠線・クリップ形状より前)

### 未起動時の挙動

本文中「アイコンは暗くなっている」= 既存の暗転表現 (彩度 0.3 + 不透明度 0.5) を踏襲する (彩度と不透明度の両方を下げる)。この暗転は未起動状態でのみ適用し、他の 3 状態では通常表示 (彩度 1.0 + 不透明度 1.0)。

### 依存する状態源

| 状態 | 状態源 | 新規/既存 |
|---|---|---|
| 未起動 | コンパニオン設定の紐付きセッション ID (なし = 未起動) | 既存 |
| 実行中 (isBusy) | Claude セッションが公開する実行中判定 | **新規** (issue #45 で追加) |
| 読み上げ中 (isSpeaking) | Claude セッションの読み上げ中判定 → 音声キューの「現在読み上げ中の companionIndex」 | **新規** (issue #45 で追加、voicevox.md の将来拡張枠を具体化) |

- 実行中判定: PTY 出力が続いている間は実行中。静止を検知したら解除。詳細は [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) を参照
- 読み上げ中判定: 音声キューが当該 Companion を読み上げ中かどうかを返す薄いファサード (状態実体を持たない)。アイコン表示は実行中と対称に Claude セッションから読み取り、音声キューの状態変化が自動で伝播する。詳細は [../backchannels/voicevox.md](../backchannels/voicevox.md) を参照

### 実装箇所

| 役割 | 責務 |
|---|---|
| コンパニオンアイコン描画 | 状態を判定してベース画像を差し替え + オーバーレイ描画 |
| アイコンプリセット | thumbnail に加えて smile / thinking バリアントの画像対応を提供 |

### 境界

- **Always**: 状態変化に駆動されて UI が自動更新される (タイマー polling しない)。優先順位判定はアイコン描画の 1 箇所に集約
- **Never**: 表情切替のために companion の永続状態 (`workspace.json`) を書き換えない。実行中 / 読み上げ中はランタイム情報のみ

---

## 関連ドキュメント

- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — 送信メカニズム (PTY へのキー送信)
- [recommend-mode.md](./recommend-mode.md) — Cmd+Enter によるレコメンド選択 UI
- [speech-history.md](./speech-history.md) — speech 履歴ビュー (コンパニオン編集シートから開く)
- [../backchannels/handoff.md](../backchannels/handoff.md) — Companion 間ハンドオフ ([ADR 0023](../../decisions/0023-companion-handoff.md))
- [../backchannels/companion-roster.md](../backchannels/companion-roster.md) — `aidea.md` 内のコンパニオン名簿自動同期
- [../tools/claude.md](../tools/claude.md) — Claude セッション側の挙動
- [agent-definition.md](./agent-definition.md) — `agent.md` によるエージェント定義・フォールバック挙動
- [../aspects/persistence.md](../aspects/persistence.md) — `workspace.json` v7 保存・Bundle テンプレ
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — SessionID / 5 概念
