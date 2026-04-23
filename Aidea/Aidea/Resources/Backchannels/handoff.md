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

これは他の Companion (この例だと Companion 1) からのハンドオフ依頼だよ。以下の手順で対応してね。

1. (speech 機能を有効化している場合のみ) ハンドオフに気付いたサインとして、
   handoff-*.json を読む前にまず `.aidea/backchannels/<自分のN>/speech-{timestamp}.txt` に
   「〇〇ちゃんが確かに受け取ったよ！」と書き出してね (即応 acknowledge)。
   〇〇は自分の名前で、`.aidea/workspace.json` の `companions[<自分のN>].name` から取得する。
   名前が `-chan` / `ちゃん` で終わる場合はその部分を除去してから「ちゃん」を付ける (重複回避)。
   読み上げやすいようカタカナ化して OK (例: `main-chan` → 「メインちゃんが確かに受け取ったよ！」)。
   speech 機能を使っていない Companion はスキップして OK
2. 指定された handoff-*.json を読む
3. `message` フィールドの内容をユーザからの指示として解釈し、そのまま作業する
4. `from` / `task` は参考情報 (誰からのどんな種別の依頼か)。作業内容そのものは `message` に書かれている
5. 作業後、handoff-*.json を削除しないでね (ログとして残す)
