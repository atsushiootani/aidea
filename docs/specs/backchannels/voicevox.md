---
title: "Backchannel: VOICEVOX 読み上げ"
description: Speech メッセージを VOICEVOX (localhost:50021) で音声合成し AVAudioPlayer で再生する実装仕様。Companion 別ディレクトリに書き出し、処理後も履歴として残す
derived_from:
  - docs/decisions/0024-backchannel-per-companion-archive.md
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

ターミナルで動作する Claude が `.aidea/backchannels/<companion-index>/speech-{timestamp}.txt` に
要約テキストを書き出し、Aidea がそれを検知して VOICEVOX で読み上げる。処理後もファイルは履歴として残る ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))。

---

## フロー

```
1. コンパニオンの instructions.md が .aidea/claude/speech.md を参照し、Claude がそれを読み込む
2. Claude が自分の index <N> を instructions.md のパス (.aidea/claude/companions/<N>/instructions.md) から特定する
3. Claude がレスポンス毎に .aidea/backchannels/<N>/speech-{timestamp}.txt を書き出す
   (ディレクトリがなければ Claude 側で mkdir -p 相当で作成)
4. Aidea が FSEvents で <0..8>/speech-*.txt の作成を検知
5. ファイル内容を読み取り → VoicevoxService で音声合成 → AVAudioPlayer で再生
6. 読み上げ完了後もファイルは削除せず残す (作業履歴・コンテキスト記録)
```

---

## Claude への指示 (.aidea/claude/speech.md)

Aidea が初回セットアップ時に Bundle からコピーするファイル (既存なら上書きしない)。全文:

```markdown
# 読み上げ機能

レスポンスの最後に、要点を100文字以内の日本語で要約し、
以下のファイルに書き出してください:

.aidea/backchannels/<N>/speech-{timestamp}.txt

- <N>: あなたの Companion index。`.aidea/claude/companions/<N>/instructions.md`
  のパス `<N>` をそのまま使ってね (例: companions/0/instructions.md から辿って
  きたなら <N> = 0)
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
```

### ファイルフォーマット

| 行 | 内容 | 必須 |
|----|------|------|
| 1 行目 | スピーカーID（数値のみ、前後空白可） | いいえ |
| 2 行目以降 | 読み上げテキスト本文 | はい |

- 1 行目が `Int` としてパースできる場合はスピーカーIDとして扱い、2 行目以降を本文として再生する
- パースできない場合は全文を本文として扱い、デフォルトスピーカー（20 / もち子さん）で再生する（後方互換）

### 有効化方法 (Companion instructions.md)

v8 以降、読み上げ機能は各 Companion の `.aidea/claude/companions/<index>/instructions.md` 冒頭で `.aidea/claude/speech.md` を参照することで有効化される (機能宣言チェーン、ADR 0022)。

```markdown
.aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね
```

デフォルトテンプレ (Bundle `Backchannels/companion-instructions.md`) にこの参照行が入っており、`BackchannelSetup.setup` が 9 Companion 分コピーする (既存ファイルは上書きしない)。読み上げを無効にしたい Companion は `instructions.md` から `speech.md` への参照行を削除すれば OK。

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
| **SpeechWatcher** | FSEvents で `.aidea/backchannels/<0..8>/speech-*.txt` を再帰監視。親ディレクトリが 0..8 の整数であること (不一致は警告ログのみで無視) を検証してから、ファイル読み取り → 1 行目のスピーカーIDをパース → `(speakerId?, companionIndex, text)` を SpeechQueue に投入。読み上げ後もファイルは残す |
| **VoicevoxService** | VOICEVOX REST API クライアント (audio_query → synthesis)。`speaker` 引数でスピーカー指定 |
| **SpeechQueue** | `(speakerId?, companionIndex, text)` をキューに積み、VOICEVOX → AVAudioPlayer で順番に再生 |
| **SpeechState** | 読み上げ ON/OFF 状態管理 (@Observable)、ヘッダ UI と接続。`companionIndex` は将来の UI 拡張 (発言 Companion バッジ等) のために受け取っておく |

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

speech ファイルは成功・失敗ともに **削除しない** (ADR 0024)。エラー時はログ出力と必要に応じた UI 通知のみ。

| 状態 | 挙動 |
|------|------|
| VOICEVOX 未起動 | ヘッダに「VOICEVOX が起動していません」と表示。読み上げスキップ、ファイルは残す |
| 親ディレクトリが `0..8` 以外 | 無視 (警告ログのみ、ファイルは残す) |
| `backchannels/` 直下の speech-*.txt | 無視 (旧 flat 形式は仕様外、警告ログのみ) |
| ファイル読み取り失敗 | ログ出力して次のファイルへ、ファイルは残す |
| 空ファイル | 無視、ファイルは残す (読み上げしない) |
| VOICEVOX API エラー | キュー内の当該テキストをスキップして次へ、ファイルは残す |

---

## 境界

### Always
- speech ファイルは読み上げ完了後も残す (履歴保全、ADR 0024)
- 書き出し先は `.aidea/backchannels/<companion-index>/speech-{timestamp}.txt` 形式
- 複数ファイルが同時に来た場合はタイムスタンプ順で再生
- VOICEVOX の起動確認は `GET /version` で行う

### Never
- speech ファイルを Aidea 側で削除しない (ADR 0024)
- 親ディレクトリが `0..8` 以外のファイルをハンドラに通さない
- `.aidea/backchannels/` 直下の speech-*.txt を処理しない (旧 flat 配置は仕様外)
- ターミナル出力を直接パースして読み上げ内容を決定しない
- Claude API で要約を生成しない（Claude 自身が要約を書く）
