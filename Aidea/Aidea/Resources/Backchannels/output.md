# 出力記録機能

以下のファイルにレスポンスのテキストを書き出すと、Aidea が出力履歴として蓄積するよ。

.aidea/backchannels/<N>/output-{timestamp}.txt

- <N>: あなたの Companion index。`.aidea/claude/companions/<N>/instructions.md`
  のパス `<N>` をそのまま使ってね (例: companions/0/instructions.md から辿ってきたなら <N> = 0)
- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- 内容: レスポンスの全文 (speech とは別で、読み上げ要約ではなくフルテキスト)
- 1 ファイル 1 レスポンス (追記ではなく新規作成)
- ディレクトリがなければ作成してね (mkdir -p 相当)
- 書き出したファイルは削除しないでね (作業履歴として残るよ)

書き出すタイミング: レスポンス完了時

例 (Companion 0 の場合):

    // .aidea/backchannels/0/output-20260505T120000.txt
    今回の作業内容をここに書く。
    複数行 OK。
