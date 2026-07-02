# inbox 機能（外部 → Companion）

Aidea の外にいるプロセス（スクリプト・cron・別のエージェント等）から、Aidea の Companion に
メッセージ（プロンプト）を送るための一方向チャネルだよ。ファイルを 1 個置くだけで、
指定した Companion がそれを通常のプロンプトとして処理する。

## 前提

- Aidea が**起動中**であること（発火点は Aidea プロセス内。起動していないと届かない）
- 宛先 Companion が未起動なら Aidea が**自動起動**してから送る
- **返信は返ってこない**（一方向）。Companion の応答は Aidea のタブに出るだけで、外部からは読めない

## 書き出し先

```
.aidea/backchannels/inbox/handoff-{YYYYMMDDTHHmmss}.json
```

- ディレクトリが無ければ作成する（`mkdir -p` 相当）
- ファイル名は `*.json` なら何でも発火するが、**`handoff-{現在時刻}.json` を推奨**
  （handoff 機能とファイル名の作法を揃えるため。ただし中身のスキーマは handoff とは別物）
- **原子的に書く**こと（`>` で直接書くと書き込み途中に検知されてパース失敗することがある）。
  一時ファイルに書いてから `mv` でリネームする

## 中身（JSON）

```json
{
  "to": "red-chan",
  "message": "main の CI が通ったか確認して、落ちてたら原因を教えて"
}
```

| フィールド | 必須 | 意味 |
|---|---|---|
| `to` | はい | 宛先 Companion。数値なら index (0..8)、文字列なら Companion 名（前後空白無視・大文字小文字無視の先頭マッチ） |
| `message` | はい | Companion に送るプロンプト本文。改行 OK。空文字は無効 |

- `from` は不要（外部送信元は index を持たないため。handoff とはここが違う）
- 余分なキー（`_note` 等）は無視される

## 送信例（シェル）

```bash
dir=.aidea/backchannels/inbox
mkdir -p "$dir"
tmp=$(mktemp)
printf '{"to":"red-chan","message":"CI の状態を確認して"}' > "$tmp"
mv "$tmp" "$dir/handoff-$(date +%Y%m%dT%H%M%S).json"
```

## 注意

- 送った本文の末尾には Aidea が自動で「返信不要」の一文を付け足す（外部に返す相手がいないため）
- 処理後もファイルは削除されず残る（履歴）。溜まったら手で掃除してよい
- Aidea 起動**前**に置いたファイルは取り込まれない（起動時の再スキャンをしない仕様）。
  Aidea が動いている状態で置くこと
- 詳細仕様: `docs/specs/backchannels/inbox.md`
