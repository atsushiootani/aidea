---
title: "Backchannel: VOICEVOX 読み上げ"
description: Speech メッセージを VOICEVOX (localhost:50021) で音声合成し AVAudioPlayer で再生する実装仕様。スピーカーはファイル1行目で指定可
derived_from: []
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
impacts:
  - docs/specs/tools/claude.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Backchannel: VOICEVOX 読み上げ

> Backchannel の Speech メッセージを VOICEVOX で音声読み上げする機能

[backchannel.md](./backchannel.md) の Speech メッセージ種別の実装仕様。

---

## 概要

ターミナルで動作する Claude が `.aidea/backchannels/speech-{timestamp}.txt` に
要約テキストを書き出し、Aidea がそれを検知して VOICEVOX で読み上げる。

---

## フロー

```
1. コンパニオンの initialPrompt が .aidea/claude/speech.md を参照し、Claude がそれを読み込む
2. Claude がレスポンス毎に .aidea/backchannels/speech-{timestamp}.txt を書き出す
3. Aidea が FSEvents で speech-*.txt の作成を検知
4. ファイル内容を読み取り → VoicevoxService で音声合成 → AVAudioPlayer で再生
5. 読み上げ完了後、ファイルを削除
```

---

## Claude への指示 (.aidea/claude/speech.md)

Aidea が初回セットアップ時に Bundle からコピーするファイル (既存なら上書きしない)。全文:

```markdown
# 読み上げ機能

レスポンスの最後に、要点を100文字以内の日本語で要約し、
以下のファイルに書き出してください:

.aidea/backchannels/speech-{timestamp}.txt

- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- 1ファイル1メッセージ（追記ではなく新規作成）
- VOICEVOXで読み上げるため、英単語はカタカナに変換すること
- 記号は省略すること

## スピーカーID

ファイルの1行目に読み上げスピーカーIDを数値のみで記述する。
2行目以降が読み上げテキスト本文。

例:

    2
    こんにちはご主人
```

### ファイルフォーマット

| 行 | 内容 | 必須 |
|----|------|------|
| 1 行目 | スピーカーID（数値のみ、前後空白可） | いいえ |
| 2 行目以降 | 読み上げテキスト本文 | はい |

- 1 行目が `Int` としてパースできる場合はスピーカーIDとして扱い、2 行目以降を本文として再生する
- パースできない場合は全文を本文として扱い、デフォルトスピーカー（20 / もち子さん）で再生する（後方互換）

### 有効化方法 (コンパニオン initialPrompt)

```
.aidea/claude/speech.md を読んで読み上げを有効にしてね
```

デフォルトコンパニオン (`CompanionStore.createDefault`) の `initialPrompt` に
上記が初期値として設定される。無効化したい場合はコンパニオン編集で空にする。

---

## VOICEVOX REST API

| 設定項目 | 値 |
|----------|-----|
| エンドポイント | `http://localhost:50021` |
| デフォルトスピーカー | 20（もち子さん） |

スピーカーは speech ファイル 1 行目の指定があればそちらを優先する。

### API フロー

1. **audio_query**: `POST /audio_query?speaker={id}&text={text}` → JSON (音声パラメータ)
2. **synthesis**: `POST /synthesis?speaker={id}` に JSON を送信 → WAV データ
3. **再生**: AVAudioPlayer で WAV を再生

---

## Aidea 側の実装コンポーネント

| コンポーネント | 責務 |
|---------------|------|
| **SpeechWatcher** | FSEvents で `.aidea/backchannels/speech-*.txt` を監視、検知時にファイル読み取り → 1 行目のスピーカーIDをパース → SpeechQueue に投入 |
| **VoicevoxService** | VOICEVOX REST API クライアント (audio_query → synthesis)。`speaker` 引数でスピーカー指定 |
| **SpeechQueue** | `(speakerId?, text)` をキューに積み、VOICEVOX → AVAudioPlayer で順番に再生 |
| **SpeechState** | 読み上げ ON/OFF 状態管理 (@Observable)、ヘッダ UI と接続 |

---

## UI: AppHeaderView

アプリ上部に常時表示されるヘッダバー。

| 要素 | 説明 |
|------|------|
| アプリアイコン | Aidea のアプリアイコン (36x36) |
| 声アイコン | `speaker.wave.2.fill` / `speaker.slash.fill` トグル |
| 再生中インジケータ | `waveform` シンボル（再生中のみ表示） |
| ステータス | エラーメッセージ（VOICEVOX 未起動等） |

デフォルト: **ON**

---

## エラーハンドリング

| 状態 | 挙動 |
|------|------|
| VOICEVOX 未起動 | ヘッダに「VOICEVOX が起動していません」と表示。読み上げスキップ |
| ファイル読み取り失敗 | ログ出力して次のファイルへ |
| 空ファイル | 無視してファイル削除 |
| VOICEVOX API エラー | キュー内の当該テキストをスキップして次へ |

---

## 境界

### Always
- speech ファイルは読み上げ完了後に削除する
- 複数ファイルが同時に来た場合はタイムスタンプ順で再生
- VOICEVOX の起動確認は `GET /version` で行う

### Never
- ターミナル出力を直接パースして読み上げ内容を決定しない
- Claude API で要約を生成しない（Claude 自身が要約を書く）
