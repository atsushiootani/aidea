---
title: "Backchannel: VOICEVOX 読み上げ"
description: Speech メッセージを VOICEVOX (localhost:50021) で音声合成し AVAudioPlayer で再生する実装仕様。Companion 別ディレクトリに書き出し、処理後も履歴として残す
derived_from:
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/companion.md
  - docs/specs/widgets/pomodoro.md
impacts:
  - docs/specs/tools/claude.md
  - docs/specs/companions/speech-history.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-02
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
3. Claude が .aidea/backchannels/<N>/speech-{timestamp}.txt を書き出す
   (ディレクトリがなければ Claude 側で mkdir -p 相当で作成)
   - 1 プロンプトで「作業開始時」と「レスポンス時」の 2 つのファイルを書き出す
   - タイムスタンプ順に順番に再生される
4. Aidea が FSEvents で <0..8>/speech-*.txt の作成を検知
5. ファイル内容を読み取り → VoicevoxService で音声合成 → AVAudioPlayer で再生
6. 読み上げ完了後もファイルは削除せず残す (作業履歴・コンテキスト記録)
```

---

## Claude への指示 (.aidea/claude/speech.md)

Aidea が初回セットアップ時に Bundle からコピーするファイル (既存なら上書きしない)。全文:

```markdown
# 読み上げ機能

以下のファイルに書き出すと VOICEVOX で音声読み上げされるよ。

.aidea/backchannels/<N>/speech-{timestamp}.txt

- <N>: あなたの Companion index。`.aidea/claude/companions/<N>/instructions.md`
  のパス `<N>` をそのまま使ってね (例: companions/0/instructions.md から辿ってきたなら <N> = 0)
- {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
- 1 行目: 読み上げスピーカーIDを数値のみで指定 (省略可、省略時はデフォルトスピーカー)
- 2 行目以降: 読み上げテキスト本文
- 1 ファイル 1 メッセージ (追記ではなく新規作成)
- ディレクトリがなければ作成してね (mkdir -p 相当)
- VOICEVOX で読み上げるため、英単語はカタカナに変換すること
- 記号は省略すること
- 句読点ではスペースを開けて、ちゃんと区切ること
- 書き出したファイルは削除しないでね (作業履歴として残るよ)

例 (Companion 0 の場合):

    // .aidea/backchannels/0/speech-20260423T164822.txt
    2
    こんにちはご主人

書き出すタイミングは「作業開始時」と「レスポンス時」の 2 回。
1 プロンプトで複数 speech ファイルを書き出して OK (timestamp 順に再生される)。

## 作業開始時

タスクを受け取ったら、作業に取り掛かる前にまず受け付けたことを書き出してね (作業開始の合図)。

例:
- 「了解 やっていくね」
- 「〜を確認してみるよ」
- 「ちょっと調べるね」

## レスポンス時

レスポンスの最後に、要点を 100 文字以内の日本語で要約して書き出してね。

## 読み上げ文面の指示がある場合

**読み上げ文面の指示がある場合は、要点ではなく指示通りの文面を書き出してください。**

instructions.md に「最初のプロンプトの読み上げ文面は "〇〇" にして」のような
指示があるときは、要約せず指定された文面をそのまま書き出すこと。

作業開始時・レスポンス時とも、文面指示があればそれが優先される。
起動時など指定文面がある場合は、作業開始の位置で指定文面を書き出し、
別途 ack speech を追加しなくてよい。
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

### 読み上げ文面の指示 (Companion 別上書き、issue #110)

各 Companion の `.aidea/claude/companions/<index>/instructions.md` に読み上げ文面の指示を書くと、その場面の speech は要約ではなく指定文面がそのまま書き出される。

**典型的なユースケース: 起動時のあいさつ固定**

```markdown
# Companion 指示書

.aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね。

最初のプロンプトの読み上げ文面は「main-chan スタンバイです！」にしてね。

## このコンパニオンの役割

(ここに固有の役割を書いてね)
```

これにより、起動時に Aidea が送る `.aidea/claude/companions/N/instructions.md を読んで従ってね` への最初の応答で、Claude は要点要約ではなく `main-chan スタンバイです！` を speech ファイルに書き出す。

**汎用性**: 文面指示は「最初のプロンプト」に限定されない。「特定の作業完了時」「エラー時」などユーザが場面を指定すれば Claude が従う (speech.md 側の方針「指示があれば指示通り、なければ要点要約」)。

**フロー上の位置づけ**: Aidea 本体の変更は不要。speech.md と instructions.md の指示書テキストだけで成立する (Claude の解釈ベース)。

### 作業開始時 (issue #113)

通常のプロンプト受付時に、作業に取り掛かる前に「了解 やっていくね」のような作業開始 speech を書き出す。応答末尾の「レスポンス時」speech (要点要約) とは別に出るため、1 プロンプトで **複数の speech ファイル** が生成される。タイムスタンプ順に再生されるので、ユーザには「作業開始 → (作業) → レスポンス (要点要約)」の順で聞こえる。

ハンドオフ受信時の ack ([handoff.md](./handoff.md) の「受信側」手順 1) を一般化し、通常プロンプトでも同じ ack speech を行う位置づけ。

**文面指示との優先関係**: 起動時など [読み上げ文面の指示](#読み上げ文面の指示-companion-別上書きissue-110) がある場合は、作業開始の位置で指定文面が書き出される (追加で ack speech は出さない)。これにより「メインちゃん スタンバイです！」のような起動文面と ack が重複しない。

**フロー上の位置づけ**: Aidea 本体の変更は不要。speech.md に「作業開始時」節を追加するだけで成立する (Claude の解釈ベース)。

### 読み上げ中 Companion の UI 反映 (issue #45)

`SpeechQueue` に `@Observable` な `currentlySpeakingIndex: Int?` を持たせ、**現在 VOICEVOX で再生中の speech の送信元 companionIndex** を公開する。

| タイミング | `currentlySpeakingIndex` |
|---|---|
| キューが空 | `nil` |
| 次のエントリの再生開始直前 | そのエントリの `companionIndex` |
| `AVAudioPlayer` 再生完了 (または VOICEVOX API エラーでスキップ) | `nil` に戻す |

`CompanionView` はこの値を監視し、`companions[N].index == currentlySpeakingIndex` な Companion を「読み上げ中」表示 (笑顔 + heart.fill) に切り替える。詳細は [../companions/companion.md#表情・状態表示-issue-45](../companions/companion.md#表情・状態表示-issue-45) を参照。

**Always**: `currentlySpeakingIndex` は単一値 (同時再生しない = キューは 1 つずつ逐次処理)。複数 Companion の speech が重なった場合、タイムスタンプ順で 1 体ずつ切り替わる。

**Never**: `SpeechState.isEnabled` が OFF のときでも `currentlySpeakingIndex` を false 立てしない (キューそのものがスキップされるため自然に `nil` のまま)。

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
| **SpeechQueue** | `(speakerId?, companionIndex, text)` をキューに積み、VOICEVOX → AVAudioPlayer で順番に再生。再生中エントリの `companionIndex` を `@Observable currentlySpeakingIndex: Int?` として外部公開 (issue #45) |
| **SpeechState** | 読み上げ ON/OFF 状態管理 (@Observable)、ヘッダ UI と接続 |

---

## UI: AppHeaderView

アプリ上部に常時表示されるヘッダバー。

| 要素 | 配置 | 説明 |
|------|------|------|
| コンパニオンビュー | 左 | 9 体のコンパニオンアイコン (`CompanionView`) |
| 読み上げトグル | コンパニオンビューの直右 | 読み上げ ON/OFF ボタン (issue #128) |
| 再生中インジケータ | 右 | `waveform` シンボル（再生中のみ表示、将来拡張） |
| ステータス | 右 | エラーメッセージ（VOICEVOX 未起動等） |

デフォルト: **ON**

### 読み上げトグル (issue #128)

ヘッダ上で **読み上げ機能を一時的に OFF にできる** ボタン。コンパニオンビューの右隣に配置する。

| 状態 | アイコン | 説明 |
|------|---------|------|
| ON (読み上げ有効) | `speaker.wave.2.fill` | クリックで OFF へトグル |
| OFF (読み上げ無効) | `speaker.slash.fill` | クリックで ON へトグル |

#### 動作

- クリック時に `SpeechState.toggle()` を呼び、`isEnabled` を反転する
- アイコンは `SpeechState.isEnabled` を見て切り替える (`@Observable` 駆動)
- ツールチップで `読み上げ ON/OFF` を提示する

#### ショートカット

- **`⌥⌘M`** で読み上げを ON/OFF トグルする (M = Mute)
- `AideaApp.swift` の「Aidea」`CommandMenu` に **「読み上げ ON/OFF」** 項目を追加し、`.keyboardShortcut("m", modifiers: [.command, .option])` を付与する
- メニュー項目のラベルは状態に応じて切り替えず固定 (`読み上げ ON/OFF`)。状態はヘッダのアイコンで提示する
- アクションは `SpeechState.toggle()` を呼ぶ (UI ボタンと同じ経路)

#### OFF 中の挙動

- **Aidea 側**: `SpeechWatcher` を停止し、`SpeechQueue` をクリアする (= VOICEVOX 再生は行わない)
- **Claude 側**: 通常どおり `.aidea/backchannels/<N>/speech-{timestamp}.txt` を書き出す。speech.md の指示に変更は無く、プロンプトや CLI 動作も変わらない (= 履歴ファイルは残る)
- **ON 切替時**: `SpeechWatcher` を再開し、`checkVoicevox()` を再実行する。**OFF 中に作成された speech ファイルは再生対象に含めない** (差分検知ではなく FSEvents の即時通知に依存しているため)。「一時的にオフ」用途として割り切る

#### 永続化

- **永続化しない** (`workspace.json` には保存しない)
- アプリ再起動時は常に ON に戻る ("一時的にオフ" 用途)

#### 境界

- **Always**: トグル UI からの状態変更は `SpeechState.toggle()` を経由する (直接 `isEnabled` を書き換えない)
- **Never**: トグル状態を `workspace.json` に保存しない (ON/OFF はランタイム情報のみ)
- **Never**: OFF 中も `currentlySpeakingIndex` は false 立てしない (キュー自体がスキップされるため自然に `nil` のまま、companion.md の Never 規約と整合)

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
