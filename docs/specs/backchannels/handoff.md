---
title: "Backchannel: コンパニオン間ハンドオフ"
description: Companion 間でタスクを受け渡す Handoff メッセージ (.aidea/backchannels/<n>/handoff-*.json) の JSON スキーマ・宛先解決・Aidea 側 Watcher/Dispatcher 実装仕様
derived_from:
  - docs/decisions/0023-companion-handoff.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
  - docs/specs/companions/companion.md
  - docs/specs/frontchannels/frontchannel.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
impacts:
  - docs/specs/backchannels/companion-roster.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-03
---

# Backchannel: コンパニオン間ハンドオフ

> 送信元 Companion から宛先 Companion へタスクを受け渡す Backchannel メッセージ

[backchannel.md](./backchannel.md) の `handoff-*.json` メッセージ種別の実装仕様。設計判断の背景は [ADR 0023](../../decisions/0023-companion-handoff.md) を参照。

---

## 概要

- 送信元 Claude が `.aidea/backchannels/<from>/handoff-{timestamp}.json` を書き出す (`<from>` は自分の Companion index)
- Aidea が FSEvents で検知し、宛先 Companion の Claude セッションに PTY で **ファイル参照メッセージ** (`.aidea/backchannels/<from>/handoff-{name}.json の作業をやってね`) を送信する
- 受信側 Claude が handoff.md の指示に従って handoff-*.json を読み、`message` 本文を作業指示として実行する
- 宛先セッションが未起動なら自動起動する。宛先タブはアクティブ化する
- 送信元 Claude は書き出したら通常どおりターンを終える (待機ループを持たない)
- ハンドオフ配送後もファイルは削除せず残す (作業履歴として保全、[ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

### なぜ本文を PTY に直接送らずファイル参照にするか

`message` 本文が長文・改行・コードブロックを含むと、PTY ペーストでの文字化け・改行誤認・ターミナル制御文字干渉のリスクが増える。本文は backchannel (ファイル) に集約し、frontchannel (PTY) は参照通知だけにすることで:

- PTY に流すテキストを固定文言の短い 1 行に抑えられる (クォート・改行・エスケープ問題を回避)
- 受信側 Claude はファイルを読む標準操作で本文を取得するため、長文・構造化データも安全に運べる
- ハンドオフ履歴が `.aidea/backchannels/` にファイルとして残り、監査・再実行が容易になる

---

## フロー

```
1. 送信元 Companion の instructions.md が .aidea/claude/handoff.md を参照し、Claude がそれを読み込む
2. 送信元 Claude が自分の index <from> を instructions.md のパスから特定する
3. 送信元 Claude が .aidea/backchannels/<from>/handoff-{timestamp}.json を書き出す
   (ディレクトリがなければ Claude 側で mkdir -p 相当で作成)
4. Aidea が FSEvents で <0..8>/handoff-*.json の作成を検知
5. HandoffWatcher が親ディレクトリ名 (<from>) を読み取り、JSON をパース
   a. JSON の `from` と親ディレクトリが一致することを検証 (不一致はエラー、ファイルは残す)
   b. (HandoffMessage, 元ファイル URL, companionIndex) を HandoffDispatcher に渡す
6. HandoffDispatcher:
   a. to を index 解決 (index 指定 or name 逆引き)
   b. 宛先 Companion が未起動なら自動起動 (CompanionLauncher 経由)
   c. 宛先 Claude セッションに ".aidea/backchannels/<from>/{filename} の作業をやってね" を送信
   d. 宛先タブをアクティブ化
7. handoff-*.json は残す (受信側 Claude が読むため + 作業履歴として、ADR 0024)
8. 受信側 Claude が handoff.md の受信側セクションに従って:
   a. speech 機能が有効 (.aidea/claude/speech.md を読み込んでいる) なら、
      handoff-*.json を読む前に acknowledge 用の speech-*.txt を書き出す (即応サイン)
      → Aidea の SpeechWatcher が検知して VOICEVOX で読み上げ → ユーザは即座に
      ハンドオフが宛先 Companion に届いたことを音で確認できる
   b. 指定された handoff-*.json を読む
   c. JSON の `message` を作業指示として解釈し、そのまま実行する
   d. 作業完了時、通常どおりレスポンス末尾で要約 speech を書き出す (既存の speech フロー)
```

### 受信時の即応 acknowledge (issue #108)

受信側 Claude がハンドオフ依頼を受け取ったタイミングで、作業着手前に短い「〇〇ちゃんが確かに受け取ったよ！」を読み上げさせる (〇〇 = 自分の Companion 名)。目的:

- ユーザがハンドオフ先 Companion の Claude が気付いたことを **音で即座に確認** できる
- **名前が入ることで「どの Companion が受け取ったか」まで同時に識別** できる (複数 Companion 並列時)
- 長文の `message` を Read ツールで読む間の無音時間が埋まり、体感レスポンスが向上する
- 作業開始 / 完了のサインが音で区切られ、複数 Companion の並列稼働時に状況把握が楽になる

**文言は「<自分の名前>ちゃんが確かに受け取ったよ！」** とする。名前の取得元は `.aidea/workspace.json` の `companions[<自分のN>].name`。名前が `-chan` / `ちゃん` で終わっている場合はその部分を除去してから「ちゃん」を付けることで重複を避ける。読み上げやすさのため英語名はカタカナ化してよい (例: `main-chan` → 「メインちゃんが確かに受け取ったよ！」、`Companion 4` → 「コンパニオンヨンちゃんが確かに受け取ったよ！」)。

**speech 機能が無効な Companion は書き出さない**。受信側 Claude が `.aidea/claude/speech.md` を読んでいない (= 機能宣言チェーン上 speech 機能を持たない) 場合は acknowledge も出さない。

Aidea 側の実装変更は **不要**。完全に `.aidea/claude/handoff.md` の受信側セクションの指示書テキストだけで実装する。

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
| `from` | `Int` (0..8) | **はい** | 送信元 Companion の index。ファイルパスの `<companion-index>` と一致すること (Aidea 側で検証、不一致は破棄) |
| `to` | `Int` (0..8) or `String` | **はい** | 宛先 Companion の index または name。解決失敗時はメッセージを破棄する |
| `task` | `String` | いいえ | ハンドオフの種別を表す任意ラベル (例: `implement` / `review` / `plan`)。UI バッジ・ログで使う |
| `message` | `String` | **はい** | 宛先 Claude に渡す作業指示の本文。PTY には流さず、受信側 Claude が handoff-*.json を自ら読んで取得する (エスケープ・改行・制御文字の心配不要) |

`from` は ADR 0024 でパスの `<companion-index>` を導入したため必須化した (以前は任意)。`task` は MVP では受信時にパースするだけで UI には反映しない (将来拡張の足場)。

`message` は長文・改行・コードブロックを含んでよい。PTY に直接流さず受信側 Claude がファイルから読むため、エスケープやターミナル制御文字を気にする必要はない (JSON 文字列としての正しいエスケープだけ守る)。

### ファイル名とパス

- パス: `.aidea/backchannels/<from>/handoff-{timestamp}.json`
- `<from>`: 送信元 Companion の index (`0..8`)
- `{timestamp}`: `YYYYMMDDTHHmmss` 形式 (既存 speech-*.txt と同じ)
- 同 timestamp でも `<from>` が異なれば衝突しない (ADR 0024 の副次的メリット)。同一 Companion が同 timestamp に複数書く場合は Claude 側で一意になるよう工夫する

---

## 宛先解決

`to` フィールドの型で分岐する:

| `to` の値 | 解決ルール |
|---|---|
| 整数 (0..8) | 当該 index のコンパニオンを直接参照 |
| 整数 (範囲外) | エラー: ファイル削除 + ログ出力 |
| 文字列 (空でない) | コンパニオン一覧を先頭から走査し、`name` を前後空白除去・大文字小文字無視で比較。最初にマッチした `index` を使う |
| 文字列 (マッチなし) | エラー: ファイル削除 + ログ出力 |
| 文字列 (空) / null | エラー: ファイル削除 + ログ出力 |

送信元 Claude が宛先 Companion の name を知るための一覧は `.aidea/claude/aidea.md` 内の自動管理セクション (`<!-- aidea:companions:start --> ... <!-- aidea:companions:end -->`) に常駐する。Aidea がコンパニオン名の変更に追従して書き換えるため、Claude は aidea.md を読むだけで最新の index ↔ name 対応表を得られる。詳細は [companion-roster.md](./companion-roster.md) を参照。

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

1. [companion.md の未起動時起動フロー](../companions/companion.md#起動フロー-claude-セッション未起動) を再利用する (セッション生成 → 初期プロンプト設定 → セッション紐付け)
2. Claude CLI の起動と初期プロンプトの自動送信は Claude セッション側が担うため、ハンドオフ側は PTY ready を検知してから **ファイル参照メッセージ**を送信する
3. PTY ready 検知は既存の自動起動の状態監視を踏襲する

### 自分自身宛 (`from == to`)

起きないことが前提だが、起きた場合も通常配送する (禁止しない)。送信元 Claude が次ターンで自分宛のメッセージを受け取る形になるだけで、ループ検出は MVP では行わない (ADR 0023)。

---

## Claude への指示 (.aidea/claude/handoff.md)

Aidea が初回セットアップ時に Bundle からコピーするファイル (既存なら上書きしない)。送信側・受信側の両方の挙動を明記する。本文想定:

```markdown
# ハンドオフ機能

## 送信側: 他の Companion にタスクを渡したいとき

ユーザから「パスして」「任せて」「依頼して」「〇〇ちゃんに振って」などと指示されたときも、この機能のことを指しているよ。

以下のファイルを書き出してね。

.aidea/backchannels/<N>/handoff-{timestamp}.json

- <N>: あなた自身の Companion index。`.aidea/claude/companions/<N>/instructions.md`
  のパス `<N>` をそのまま使ってね
- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- ディレクトリがなければ作成してね (mkdir -p 相当)
- 1 ファイル 1 ハンドオフ (追記ではなく新規作成)
- 書き終わったら通常どおりターンを終えてよい。返信を待機するループは作らないこと
- 書き出したファイルは削除しないでね (作業履歴として残るよ)

### JSON スキーマ

| フィールド | 必須 | 意味 |
|---|---|---|
| `from` | はい | 自分の index (0..8)。パスの <N> と同じ数値にすること |
| `to`   | はい | 宛先 Companion の index (0..8) または name |
| `task` | いいえ | 種別ラベル (例: implement / review / plan) |
| `message` | はい | 宛先 Claude に送信する本文。長文・改行・コードブロック OK (JSON としての正しいエスケープだけ守る) |

例 (index 指定、Companion 1 が送信):

    // .aidea/backchannels/1/handoff-20260423T163907.json
    {
      "from": 1,
      "to": 0,
      "task": "implement",
      "message": "issue #77 を計画に従って実装してね"
    }

例 (name 指定、Companion 3 が送信):

    // .aidea/backchannels/3/handoff-20260423T164000.json
    {
      "from": 3,
      "to": "main-chan",
      "task": "implement",
      "message": "今日最優先の issue は #77。計画に従って実装お願い"
    }

## 受信側: 「.aidea/backchannels/<N>/handoff-*.json の作業をやってね」と言われたとき

Aidea から以下のような短いメッセージが届くことがあるよ。

    .aidea/backchannels/1/handoff-20260423T162737.json の作業をやってね

これは他の Companion からのハンドオフ依頼だよ。以下の手順で対応してね。

1. (speech 機能を有効化している場合のみ) ハンドオフに気付いたサインとして、
   handoff-*.json を読む前に自分の .aidea/backchannels/<自分のN>/speech-{timestamp}.txt に
   「<自分の名前>ちゃんが確かに受け取ったよ！」を書き出す (即応 acknowledge、issue #108)。
   自分の名前は `.aidea/workspace.json` の `companions[<自分のN>].name` から取得。
   名前末尾の `-chan` / `ちゃん` は除去し、読み上げやすいようカタカナ化 (例: `main-chan` → 「メインちゃんが確かに受け取ったよ！」)
2. 指定された handoff-*.json を読む
3. `message` フィールドの内容をユーザからの指示として解釈し、そのまま作業する
4. `from` / `task` は参考情報 (誰からのどんな種別の依頼か)。作業内容そのものは `message` に書かれている
5. 作業後、handoff-*.json を削除しないでね (ログとして残す)
```

### ファイルフォーマット

- 文字コード: UTF-8
- 拡張子: `.json` 固定
- JSON パース失敗 / 必須フィールド欠落 / `from` とパスの `<companion-index>` 不一致 → ログ出力 + 必要に応じて UI 通知、ファイルは残す (監査用)

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
| **HandoffMessage** | `handoff-*.json` をデコードするデータ構造。`from` は Int (0..8) 必須、`to` は Int または String どちらも受け付ける |
| **HandoffWatcher** | FSEvents で `.aidea/backchannels/<0..8>/handoff-*.json` を再帰監視。親ディレクトリ名を読み取り、JSON の `from` と一致することを検証してから HandoffDispatcher に渡す。ファイルは削除せず残す |
| **HandoffDispatcher** | 宛先解決 → Companion 自動起動 (必要時) → 宛先 Claude セッションにファイル参照メッセージを送信 → タブアクティブ化。`message` 本文は PTY に流さない (受信側 Claude がファイルから読む) |

---

## UI 動作 (MVP)

- **宛先タブの自動アクティブ化**: Frontchannel と同じくメッセージ送信後に対象 Session をアクティブ化する
- **送信元タブの表示変更**: MVP では行わない (将来 `task` ラベルを使ったバッジ表示を追加する足場を残す)
- **エラー通知**: パース失敗・宛先不明時はヘッダのエラー表示領域に短文で出す (SpeechWatcher が VOICEVOX 未起動時に出しているのと同じ枠を再利用)。ユーザ操作で消える

ハンドオフ履歴の UI (サイドパネル / トースト) は別チケットに切り出し、MVP では実装しない。

---

## エラーハンドリング

ハンドオフファイルは成功時・失敗時ともに削除しない (Always 節のとおりログ/再実行用途で保持する)。エラー時に行うのはログ出力と必要に応じた UI 通知のみ。

| 状態 | 挙動 |
|---|---|
| JSON パース失敗 | ログ出力 + ヘッダにエラー 1 行表示 (ユーザが気付けるよう可視化する。Claude 側の書き損じも UI に出ることで即座に差し戻し依頼できる) |
| 親ディレクトリが `0..8` 以外 | 無視 (警告ログのみ) |
| `backchannels/` 直下の handoff-*.json | 無視 (旧 flat 形式は仕様外、警告ログのみ) |
| `from` 欠落 / 範囲外 / 親ディレクトリと不一致 | ログ出力 + ヘッダにエラー 1 行表示 |
| `to` 欠落 / 型不正 / 範囲外 index / name 未マッチ | ログ出力 + ヘッダにエラー 1 行表示 |
| `message` 欠落 / 空文字 | ログ出力 |
| 宛先 Companion の自動起動失敗 | ログ出力 + ヘッダにエラー表示 |
| PTY 未 ready で `send` 失敗 | 自動起動完了を待ってから送る。タイムアウト時はログ出力 |
| 同 handoff ファイルが同時に複数 | FSEvents のタイムスタンプ順で逐次処理 (既存 SpeechWatcher と同じ) |

---

## 境界

### Always
- handoff ファイルは残す (受信側 Claude が読むため + 作業履歴として、ADR 0024)
- 書き出し先は `.aidea/backchannels/<from>/handoff-{timestamp}.json` 形式
- `from` は必須。JSON 内の `from` とパスの `<companion-index>` は一致することを検証する
- frontchannel に流すのは固定文言のファイル参照メッセージ (`.aidea/backchannels/<from>/{filename} の作業をやってね`) 1 行だけ
- 宛先が未起動なら自動起動してから送信する
- 送信元が自分自身宛 (`from == to`) でも通常配送する (MVP ではループ検出しない)
- `to` は index (Int) または name (String) の両方を受け付ける

### Never
- handoff ファイルを Aidea 側で削除しない (ADR 0024)
- 親ディレクトリが `0..8` 以外のファイルをハンドラに通さない
- `.aidea/backchannels/` 直下の handoff-*.json を処理しない (旧 flat 配置は仕様外)
- 宛先 Claude セッションで待機ループを作らない (ADR 0023)
- `message` 本文を PTY (frontchannel) 経由で直接送信しない。受信側 Claude がファイルを読む経路に統一する
- `message` 本文を Aidea 側で加工・変換しない (Frontchannel の原則と同じ)
- ハンドオフ履歴を `workspace.json` に永続化しない (ランタイム情報のみ)
- 循環検出を MVP で実装しない (将来の拡張ポイント)
- ハンドオフ成立時に Claude API を経由して再解釈しない
