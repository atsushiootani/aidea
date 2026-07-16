---
title: レコメンドモード
description: Cmd+Enter で起動するコンパニオンプロンプト選択 UI・レコメンド状態と設定ストア・Scene 解決とキー操作
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/companions/companion.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/persistence.md
  - docs/specs/sessions/claude.md
  - docs/specs/sessions/filer.md
  - docs/specs/sessions/git.md
  - docs/specs/sessions/git-diff.md
  - docs/specs/sessions/kit.md
  - docs/specs/sessions/preview.md
  - docs/specs/sessions/terminal.md
  - docs/specs/sessions/web.md
  - docs/specs/aspects/view-hierarchy.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# レコメンドモード

> Cmd+Enter でコンパニオンにレコメンドプロンプトを提示し、選択・送信する UI

コンパニオンに [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) 経由でプロンプトを送る上位 UI。
コンパニオン本体は [companion.md](./companion.md) を参照。

---

## 概要

**レコメンドモード (Recommend Mode)** は、どのビューからでも Cmd+Enter で起動できる
コンパニオンへのプロンプト選択 UI。現在のビューに応じたレコメンドプロンプトを
コンパニオンアイコンの吹き出しに最大 3 つ表示し、選択して送信する。

---

## フロー

```
1. ユーザーがどのビューでも Cmd+Enter を押下
2. ヘッダのコンパニオンビューにフォーカスが移る
3. コンパニオン 0 号に吹き出しが表示される
4. 吹き出しに現在のビューに応じたレコメンドプロンプトが最大 3 つ縦に並ぶ
5. 上下キーでプロンプトを選択
6. 左右キーでコンパニオンを切替（吹き出しも一緒に移動、プロンプトは同じ）
7. 決定キー（Enter）で送信
   - 選択したコンパニオンの Claude セッションをアクティブにする
   - プロンプトを PTY にキー送信する
8. Esc でレコメンドモードを終了
```

---

## UI

```
┌─────────────────────────────────────────────────┐
│  [😺] [🦁] [🐦] [🐱] [🦊] [🐦] [🦋] [🦋]  + │  ← ヘッダ
│         ↑                                        │
│    ┌─────────────────┐                           │
│    │ コミットして      │                           │
│    │ プッシュして      │  ← 吹き出し（レコメンド）  │
│    │ PRを作って        │                           │
│    └─────────────────┘                           │
├─────────────────────────────────────────────────┤
│                   メインコンテンツ                  │
└─────────────────────────────────────────────────┘
```

- 吹き出しは選択中のコンパニオンアイコンの下に表示
- 選択中のプロンプトはハイライト表示
- 左右キーでコンパニオンを変えると、吹き出しが移動する
- プロンプトの内容は変わらない（コンパニオン共通）

---

## レコメンドプロンプトの提供

各ビュー（Tool の SessionState）が「**現在の Scene 識別子**」を提供する。Scene に紐付くプロンプト一覧自体はレコメンド設定ストア (起動時に `default-workspace.json` から流入する) が SSoT。

### プロトコル

各ビューの SessionState は「現在の Scene 識別子を返す」操作を実装する (該当 Scene がなければ返さない)。

### 初期定義 (Bundle 同梱の `default-workspace.json` の `recommends` に格納)

| Scene | レコメンドプロンプト (初期値) | `defaultCompanionIndex` |
|--------|---------------------|---|
| `git:workingChanges` | `"コミットして"` `"プッシュして"` `"PRを作って"` | `0` |
| `git:prPreview` | `"PRをマージして"` `"レビューして"` | `0` |
| `gitDiff:workingChanges` | `"コミットして"` `"プッシュして"` `"PRを作って"` | `0` |
| `gitDiff:prPreview` | `"PRをマージして"` `"レビューして"` | `0` |
| `claude:0` … `claude:8` | `[]` (空。ユーザが各 Companion の役割に応じて追加) | Scene 識別子末尾の index と同値 (自 Companion) |
| `filer` | `[]` | `0` |
| `terminal` | `[]` | `0` |
| `preview` | `[]` | `0` |
| `kit` | `[]` | `0` |
| `web` | `[]` | `0` |
| 上記以外 | エントリ無し → Cmd+Enter は何もしない | — |

- **Claude Scene のみ `defaultCompanionIndex` が自 Companion に一致する** (`claude:5` なら `5`)。これにより Claude セッションで Cmd+Enter した際に、最初に選択されるのが「そのセッション自身が紐付く Companion」になる。
- 他セッションの初期 `defaultCompanionIndex` は `0` (= Companion 1)。ユーザがプロンプト編集エリアから変更できる。
- `prompts` が空の Scene では Cmd+Enter しても吹き出しが出ない (レコメンドなし)。ユーザがプロンプト編集エリアで追加することで有効化される。

新たな Scene へのプロンプト追加は `default-workspace.json` の `recommends` を編集するか、実行時にプロンプト編集エリアから編集する (コードへのハードコードは禁止)。

将来の拡張例 (参考):

| ビュー | レコメンドプロンプト例 |
|--------|----------------------|
| Filer | `"このファイルをレビューして: {path}"` |
| Preview | `"このドキュメントを翻訳して"` |
| Claude (Companion 別) | テスト担当 Companion なら `"テスト実行して"`、レビュー担当なら `"差分をレビューして"` |

---

## キー操作まとめ

| キー | 動作 |
|------|------|
| **Cmd+Enter** | レコメンドモードに入る |
| **↑ / ↓** | プロンプトを選択 |
| **← / →** | コンパニオンを選択（吹き出しが移動） |
| **Enter** | プロンプトを送信、レコメンドモード終了 |
| **Esc** | レコメンドモードをキャンセル |

---

## 状態管理

レコメンドモードのランタイム状態として以下を保持する。

| 状態 | 用途 |
|---|---|
| モード中か | レコメンドモード中かどうか |
| 選択中のコンパニオン | 左右キーで移動する選択位置 |
| 選択中のプロンプト | 上下キーで移動する選択位置 |
| プロンプト一覧 | 現在表示中のプロンプト一覧 |

### 実装コンポーネント

| 役割 | 責務 |
|---|---|
| レコメンド状態 | レコメンドモードのランタイム状態。有効化・無効化とプロンプト・コンパニオン選択のループ移動を管理する |
| レコメンド設定ストア | Scene ごとの設定をインメモリで保持する。永続化はワークスペーススナップショット管理経由で `workspace.json` v7 に統合される |
| Scene 設定 | Scene ごとのプロンプト一覧とデフォルトコンパニオン index を保持するデータ構造 |
| プロンプト編集エリア | 各セッションの本体 View 下部に挿入される編集 UI。表示中 Scene のプロンプト追加/削除とデフォルトコンパニオンの切替を行う |

SessionRegistry がセッション View を生成する際、**Git / GitDiff 以外**の各セッション View を本体 + プロンプト編集エリアの縦並びにラップする統一パターンを取る。GitDiff は自身のコンテナ側で挿入済みのため二重挿入しない。

Scene キー (`"git:prPreview"` `"git:workingChanges"` 等) は各 SessionState が文脈に応じて生成し、
レコメンド設定ストアから対応エントリを引く。エントリが無ければ空扱い (Cmd+Enter 無反応)。

`default-workspace.json` から流入する初期エントリが SSoT。コード内にデフォルトプロンプトのハードコードは置かない (詳細は [../frontchannels/scene.md](../frontchannels/scene.md))。

---

## 境界

### Always
- Cmd+Enter はどのビューからでも起動できる
- レコメンドモード中は他のキー操作をブロックする
- 送信後に Claude セッションをアクティブタブにする

### Confirm First
- レコメンドプロンプトが空のビューでは Cmd+Enter は何もしない

### Never
- レコメンドモード中にコンパニオンの追加・編集はできない
- 複数プロンプトの一括送信はしない
