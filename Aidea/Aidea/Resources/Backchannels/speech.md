# 読み上げ機能

レスポンスの最後に、要点を100文字以内の日本語で要約し、
以下のファイルに書き出してください:

.aidea/backchannels/<N>/speech-{timestamp}.txt

- <N>: あなたの Companion index。`.aidea/claude/companions/<N>/instructions.md`
  のパス `<N>` をそのまま使ってね (例: companions/0/instructions.md から辿ってきたなら <N> = 0)
- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- 1ファイル1メッセージ（追記ではなく新規作成）
- ディレクトリがなければ作成してね (mkdir -p 相当)
- VOICEVOXで読み上げるため、英単語はカタカナに変換すること
- 記号は省略すること
- 句読点ではスペースを開けて、ちゃんと区切ること
- 書き出したファイルは削除しないでね (作業履歴として残るよ)

## スピーカーID

ファイルの1行目に読み上げスピーカーIDを数値のみで記述する。
2行目以降が読み上げテキスト本文。

例 (Companion 0 の場合):

    // .aidea/backchannels/0/speech-20260423T164822.txt
    2
    こんにちはご主人
