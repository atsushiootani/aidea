---
title: "Backchannel: コンパニオン間ハンドオフ"
description: Companion 間でタスクを受け渡す Handoff メッセージ (.aidea/backchannels/handoff-*.json) の JSON スキーマ・宛先解決・Aidea 側 Watcher/Dispatcher 実装仕様
derived_from:
  - docs/decisions/0023-companion-handoff.md
  - docs/specs/companions/companion.md
  - docs/specs/frontchannels/frontchannel.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Backchannel: コンパニオン間ハンドオフ

> 送信元 Companion から宛先 Companion へタスクを受け渡す Backchannel メッセージ

[backchannel.md](./backchannel.md) の `handoff-*.json` メッセージ種別の実装仕様。設計判断の背景は [ADR 0023](../../decisions/0023-companion-handoff.md) を参照。

---

## 概要

- 送信元 Claude が `.aidea/backchannels/handoff-{timestamp}.json` を書き出す
- Aidea が FSEvents で検知し、宛先 Companion の Claude セッションに PTY で `message` 本文を送信する
- 宛先セッションが未起動なら自動起動する。宛先タブはアクティブ化する
- 送信元 Claude は書き出したら通常どおりターンを終える (待機ループを持たない)

---

## フロー

```
1. 送信元 Companion の instructions.md が .aidea/claude/handoff.md を参照し、Claude がそれを読み込む
2. 送信元 Claude が .aidea/backchannels/handoff-{timestamp}.json を書き出す
3. Aidea が FSEvents で handoff-*.json の作成を検知
4. HandoffWatcher が JSON をパースし、HandoffDispatcher に渡す
5. HandoffDispatcher:
   a. to を index 解決 (index 指定 or name 逆引き)
   b. 宛先 Companion が未起動なら自動起動 (CompanionLauncher 経由)
   c. 宛先 ClaudeSessionState.terminalView.send(txt: message + "\r")
   d. 宛先タブをアクティブ化
6. 処理完了後、handoff-*.json を削除
```

---

## JSON スキーマ

```json
{
  "from": 1,
  "to": "main-chan",
  "task": "implement",
  "message": "issue #77 を計画に従って実装してね"
}
```

### フィールド

| フィールド | 型 | 必須 | 意味 |
|---|---|---|---|
| `from` | `Int` (0..8) or `String` | いいえ | 送信元 Companion の index または name。UI 表示・ログ用途。未指定でも動作する |
| `to` | `Int` (0..8) or `String` | **はい** | 宛先 Companion の index または name。解決失敗時はメッセージを破棄する |
| `task` | `String` | いいえ | ハンドオフの種別を表す任意ラベル (例: `implement` / `review` / `plan`)。UI バッジ・ログで使う |
| `message` | `String` | **はい** | 宛先 Claude に送信する本文。PTY にそのまま `send(txt:)` される (末尾 `\r` は Dispatcher 側で付与) |

`from` / `task` は MVP では受信時にパースするだけで UI には反映しない (将来拡張の足場)。

### ファイル名

- パターン: `handoff-{timestamp}.json`
- `{timestamp}`: `YYYYMMDDTHHmmss` 形式 (既存 speech-*.txt と同じ)
- 同ミリ秒に複数ファイルを作る場合は Claude 側で一意になるよう工夫する (衝突時は FSEvents で最後に書かれた方が残る挙動)

---

## 宛先解決

`to` フィールドの型で分岐する:

| `to` の値 | 解決ルール |
|---|---|
| 整数 (0..8) | `CompanionStore.companions[to]` を直接参照 |
| 整数 (範囲外) | エラー: ファイル削除 + ログ出力 |
| 文字列 (空でない) | `CompanionStore.companions` を先頭から走査し、`name` を前後空白除去・大文字小文字無視で比較。最初にマッチした `index` を使う |
| 文字列 (マッチなし) | エラー: ファイル削除 + ログ出力 |
| 文字列 (空) / null | エラー: ファイル削除 + ログ出力 |

name 検索のマッチ例:

| companions[].name | `to` の値 | マッチ |
|---|---|---|
| `"main-chan"` | `"main-chan"` | ✅ |
| `"main-chan"` | `"Main-Chan"` | ✅ (case-insensitive) |
| `"main-chan"` | `" main-chan "` | ✅ (trim) |
| `"main-chan"` | `"main_chan"` | ❌ |
| `"main-chan"` | `"mainchan"` | ❌ |

### 未起動の宛先

解決で得た `index` の Companion が `sessionID == nil` の場合:

1. [companion.md の未起動時起動フロー](../companions/companion.md#起動フロー-claude-セッション未起動) を再利用する (`registry.createSession` → `ClaudeSessionState.companionPrompt` にセット → `store.bind`)
2. Claude CLI の起動と `companionPrompt` の自動送信は `ClaudeSessionState.autoStartClaude` が担うため、ハンドオフ側は PTY ready を検知してから `message` を送信する
3. PTY ready 検知は既存の `autoStartClaude` の状態監視を踏襲する (詳細は実装時に `ClaudeSessionState` と合わせて詰める)

### 自分自身宛 (`from == to`)

起きないことが前提だが、起きた場合も通常配送する (禁止しない)。送信元 Claude が次ターンで自分宛のメッセージを受け取る形になるだけで、ループ検出は MVP では行わない (ADR 0023)。

---

## Claude への指示 (.aidea/claude/handoff.md)

Aidea が初回セットアップ時に Bundle からコピーするファイル (既存なら上書きしない)。本文想定:

```markdown
# ハンドオフ機能

他の Companion にタスクを受け渡したいときは、以下のファイルを書き出してね。

.aidea/backchannels/handoff-{timestamp}.json

- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- 1 ファイル 1 ハンドオフ (追記ではなく新規作成)
- 書き終わったら通常どおりターンを終えてよい。返信を待機するループは作らないこと

## JSON スキーマ

| フィールド | 必須 | 意味 |
|---|---|---|
| `from` | いいえ | 自分の index (0..8) または name |
| `to`   | はい   | 宛先 Companion の index (0..8) または name |
| `task` | いいえ | 種別ラベル (例: implement / review / plan) |
| `message` | はい | 宛先 Claude に送信する本文 |

例 (index 指定):

    {
      "from": 1,
      "to": 0,
      "task": "implement",
      "message": "issue #77 を計画に従って実装してね"
    }

例 (name 指定):

    {
      "from": "concier-chan",
      "to": "main-chan",
      "task": "implement",
      "message": "今日最優先の issue は #77。計画に従って実装お願い"
    }
```

### ファイルフォーマット

- 文字コード: UTF-8
- 拡張子: `.json` 固定
- JSON パース失敗 / 必須フィールド欠落 → ログ出力してファイル削除、送信スキップ

### 有効化方法 (コンパニオン instructions.md)

ハンドオフを使いたい Companion の `.aidea/claude/companions/<index>/instructions.md` 冒頭に以下を追記する:

```
.aidea/claude/handoff.md を読んでハンドオフ機能を有効にしてね
```

参照を書かない Companion はハンドオフを行わない (機能宣言チェーン規約に準拠)。

---

## Aidea 側の実装コンポーネント

| コンポーネント | 責務 |
|---|---|
| **HandoffMessage** | `handoff-*.json` をデコードする Codable 構造体。`to` / `from` は `Int` / `String` どちらも受け付ける enum (`.index(Int)` / `.name(String)`) |
| **HandoffWatcher** | FSEvents で `.aidea/backchannels/handoff-*.json` を監視し、検知時に HandoffDispatcher に投げる (SpeechWatcher と同じパターン) |
| **HandoffDispatcher** | JSON をパース → 宛先解決 → Companion 自動起動 (必要時) → `ClaudeSessionState.terminalView.send(txt:)` → タブアクティブ化 → ファイル削除 |

配置: `Services/Backchannel/Handoff/` ディレクトリを新設し 3 ファイルを収める。

`HandoffDispatcher` は `CompanionStore` / `SessionRegistry` / `LayoutConfig` を参照する必要があるため、`AideaApp` から依存を注入する (既存 `BackchannelSetup` と並ぶ位置付け)。

---

## UI 動作 (MVP)

- **宛先タブの自動アクティブ化**: Frontchannel と同じく `send(txt:)` 後に対象 Session をアクティブ化する
- **送信元タブの表示変更**: MVP では行わない (将来 `task` ラベルを使ったバッジ表示を追加する足場を残す)
- **エラー通知**: パース失敗・宛先不明時はヘッダのエラー表示領域に短文で出す (SpeechWatcher が VOICEVOX 未起動時に出しているのと同じ枠を再利用)。ユーザ操作で消える

ハンドオフ履歴の UI (サイドパネル / トースト) は別チケットに切り出し、MVP では実装しない。

---

## エラーハンドリング

| 状態 | 挙動 |
|---|---|
| JSON パース失敗 | ログ出力 → ファイル削除。エラーは UI に出さない (Claude 側の書き損じを自己修復させる) |
| `to` 欠落 / 型不正 / 範囲外 index / name 未マッチ | ログ出力 → ファイル削除。ヘッダにエラー 1 行表示 |
| `message` 欠落 / 空文字 | ログ出力 → ファイル削除 |
| 宛先 Companion の自動起動失敗 | ログ出力 → ファイル削除。ヘッダにエラー表示 |
| PTY 未 ready で `send` 失敗 | 自動起動完了を待ってから送る。タイムアウト時はログ + ファイル削除 |
| 同 handoff ファイルが同時に複数 | FSEvents のタイムスタンプ順で逐次処理 (既存 SpeechWatcher と同じ) |

---

## 境界

### Always
- handoff ファイルは送信完了後に削除する
- 宛先が未起動なら自動起動してから送信する
- 送信元が自分自身宛 (`from == to`) でも通常配送する (MVP ではループ検出しない)
- `to` は index (Int) または name (String) の両方を受け付ける

### Never
- 宛先 Claude セッションで待機ループを作らない (ADR 0023)
- `message` 本文を Aidea 側で加工・変換しない (Frontchannel の原則と同じ)
- ハンドオフ履歴を `workspace.json` に永続化しない (ランタイム情報のみ)
- 循環検出を MVP で実装しない (将来の拡張ポイント)
- ハンドオフ成立時に Claude API を経由して再解釈しない
