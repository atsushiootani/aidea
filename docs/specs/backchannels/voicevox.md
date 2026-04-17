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
```

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
| Speaker | 20（もち子さん） |

### API フロー

1. **audio_query**: `POST /audio_query?speaker=20&text={text}` → JSON (音声パラメータ)
2. **synthesis**: `POST /synthesis?speaker=20` に JSON を送信 → WAV データ
3. **再生**: AVAudioPlayer で WAV を再生

---

## Aidea 側の実装コンポーネント

| コンポーネント | 責務 |
|---------------|------|
| **SpeechWatcher** | FSEvents で `.aidea/backchannels/speech-*.txt` を監視、検知時にファイル読み取り → SpeechQueue に投入 |
| **VoicevoxService** | VOICEVOX REST API クライアント (audio_query → synthesis) |
| **SpeechQueue** | テキストをキューに積み、VOICEVOX → AVAudioPlayer で順番に再生 |
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
