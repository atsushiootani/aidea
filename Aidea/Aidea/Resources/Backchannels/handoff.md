# ハンドオフ機能

## 送信側: 他の Companion にタスクを渡したいとき

ユーザから「パスして」「任せて」「依頼して」「〇〇ちゃんに振って」などと指示されたときも、この機能のことを指しているよ。

以下のファイルを書き出してね。

.aidea/backchannels/handoff-{timestamp}.json

- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- 1 ファイル 1 ハンドオフ (追記ではなく新規作成)
- 書き終わったら通常どおりターンを終えてよい。返信を待機するループは作らないこと

### JSON スキーマ

| フィールド | 必須 | 意味 |
|---|---|---|
| `from` | いいえ | 自分の index (0..8) または name |
| `to`   | はい   | 宛先 Companion の index (0..8) または name |
| `task` | いいえ | 種別ラベル (例: implement / review / plan) |
| `message` | はい | 宛先 Claude に送信する本文。長文・改行・コードブロック OK (JSON としての正しいエスケープだけ守る) |

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

## 受信側: 「.aidea/backchannels/handoff-*.json の作業をやってね」と言われたとき

Aidea から以下のような短いメッセージが届くことがあるよ。

    .aidea/backchannels/handoff-20260423T162737.json の作業をやってね

これは他の Companion からのハンドオフ依頼だよ。以下の手順で対応してね。

1. 指定された handoff-*.json を読む
2. `message` フィールドの内容をユーザからの指示として解釈し、そのまま作業する
3. `from` / `task` は参考情報 (誰からのどんな種別の依頼か)。作業内容そのものは `message` に書かれている
4. 作業後、handoff-*.json を削除する必要はない (ログとして残す)
