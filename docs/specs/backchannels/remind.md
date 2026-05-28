---
title: "Backchannel: リマインド"
description: Companion がトリガ時刻と speech 内容をファイルに書き出し、Aidea が指定時刻に VOICEVOX で読み上げる遅延発火型 Backchannel。スケジュール取得は Companion 側の責務、Aidea はファイル監視とタイマー発火のみを担う。ヘッダに次予定 1 件と Popover の一覧 UI を持つ
derived_from:
  - docs/decisions/0024-backchannel-per-companion-archive.md
  - docs/specs/backchannels/voicevox.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-27
---

# Backchannel: リマインド

> Companion がトリガ時刻と speech 内容をファイルに書き出し、Aidea が指定時刻に VOICEVOX で読み上げる遅延発火型 Backchannel

[backchannel.md](./backchannel.md) のメッセージ種別のひとつ。speech メッセージの「予約発火版」として実装される。

---

## 概要

ユーザが Companion (例: concier-chan) に「この予定を N 分前にリマインドして」と伝えると、Companion がトリガ時刻と読み上げ文面を計算してファイルに書き出す。Aidea はそのファイルをファイル名のタイムスタンプ通りにスケジューリングし、指定時刻に VOICEVOX で読み上げる。

### 設計原則

1. **Aidea はスケジュール取得を持たない** — Google Calendar 等の予定取得は Companion 側の責務 (MCP / 手入力 / 任意の手段)。Aidea はリマインド機能 = タイマー発火のみを提供する
2. **Aidea は IDE にロックインしない** — Companion 側の指示書 (`Backchannels/remind.md`) は Bundle 同梱で `.aidea/claude/remind.md` に配置されるが、Companion はファイル書き出しだけ覚えればよい。スケジュール取得手段は問わない
3. **ファイルが API** — Companion → Aidea の通知はファイル配置のみ。トリガ時刻はファイル名にエンコード、発火後はリネームで状態を表現する
4. **発火点は Aidea** — Aidea が起動中であることを前提とする。cron や外部スケジューラに依存しない

---

## フロー

```
1. ユーザ → Companion: 「14:00 の打ち合わせを 1 分前にリマインドして」
2. Companion: トリガ時刻 (= 13:59) と読み上げ文面を計算
3. Companion: .aidea/backchannels/<N>/remind-{YYYYMMDDTHHmmss}.txt を書き出す
   - {YYYYMMDDTHHmmss} はトリガ時刻 (= 発火時刻)
   - ファイル内容は speech ファイルと同じ形式
4. Aidea (RemindWatcher) が FSEvents で検知 → RemindScheduler に登録
5. RemindScheduler が指定時刻まで待機し、トリガ時刻に SpeechQueue へ投入
6. SpeechQueue が VOICEVOX で読み上げ (speech ファイルと同じ再生経路)
7. 発火後、Aidea が当該ファイルを remind-{ts}.fired.txt にリネーム
```

---

## ファイル仕様

### パスとファイル名

```
.aidea/backchannels/<companion-index>/remind-{YYYYMMDDTHHmmss}.txt
```

| 部分 | 内容 |
|---|---|
| `<companion-index>` | 書き出した Companion の index (`0..8`)。読み上げ時もこの Companion として発話する (表情・読み上げ中インジケータも同じ扱い) |
| `{YYYYMMDDTHHmmss}` | トリガ時刻 (= 発火時刻)。Companion のローカルタイムゾーン (システム時刻) として解釈する。タイムゾーン指定なしの 14 桁固定 |

### ファイル内容

speech ファイルと同じフォーマット ([voicevox.md](./voicevox.md) を参照)。

| 行 | 内容 | 必須 |
|----|------|------|
| 1 行目 | スピーカーID (数値のみ、前後空白可) | いいえ |
| 2 行目以降 | 読み上げテキスト本文 | はい |

- 1 行目が `Int` としてパースできる場合はスピーカーID、それ以外は本文の一部として扱う (speech と同じ後方互換ルール)
- 英単語はカタカナ化、句読点はスペース区切り (VOICEVOX 制約)

### 例

```
// .aidea/backchannels/6/remind-20260527T135900.txt
2
ご主人 あと1分で 打ち合わせ だよ 準備してね
```

→ 2026-05-27 13:59:00 に Companion 6 (concier-chan) として speaker 2 (四国めたん) が読み上げる。

### 発火後のリネーム

発火が完了したファイルは末尾に `.fired` を挿入してリネームする。

```
remind-20260527T135900.txt   ← 発火前
remind-20260527T135900.fired.txt   ← 発火後
```

- リネーム後は監視対象外になる (後述のパターンマッチ仕様により自動的に除外される)
- ファイル本体は削除しない (履歴保全、ADR 0024 と整合)

---

## ファイル監視

### 監視パターン

Aidea (RemindWatcher) は `.aidea/backchannels/` 配下を FSEvents で再帰監視し、以下を満たすファイルのみを処理する。

- 親ディレクトリ名が `0..8` の整数
- ファイル名が **厳密な** 正規表現 `^remind-\d{8}T\d{6}\.txt$` にマッチする

`remind-{ts}.fired.txt` は中間に `.fired` を含むため上記パターンにマッチせず、自動的に除外される。

### 発火スケジューリング

ファイルを検知したら以下を実行する。

```
1. ファイル名から YYYYMMDDTHHmmss を抽出し、システム時刻として Date に変換する
   - パース失敗 → 警告ログ、ファイルはそのまま放置 (.fired にしない)
2. トリガ時刻 vs 現在時刻 で分岐:
   a. トリガ時刻 > 現在時刻 → 差分秒数だけ待機後に発火 (タイマー登録)
   b. トリガ時刻 <= 現在時刻 → 「過去のリマインド」として処理:
      - 警告ログを出力
      - ファイル本体は読み上げず .fired にリネームする
      (Aidea 起動前に発火予定だった場合の取りこぼし扱い)
3. 発火時:
   - ファイル内容を読み取り、speech ファイルと同じパース処理を行う
   - (speakerId?, companionIndex, text) を SpeechQueue に投入
   - 投入直後にファイル名を remind-{ts}.fired.txt にリネーム
```

### 起動時スキャン

Aidea 起動時 (および `projectRoot` 切替時)、`.aidea/backchannels/<0..8>/` 配下を走査し、上記パターンに一致する全ファイルを **FSEvents 検知時と同じロジック** で処理する。これにより前回終了時に未発火だったタイマーを復元する。

---

## Companion 側の指示 (`.aidea/claude/remind.md`)

Aidea が初回セットアップ時に Bundle (`Backchannels/remind.md`) からコピーする指示書。Companion はこれを読んでリマインドファイルの書き出し方を学習する。

### 指示書の骨子

- 書き出し先パスとファイル名形式 (上記「ファイル仕様」と同じ)
- 内容フォーマット (speech と同じ)
- トリガ時刻の計算手順 (予定開始時刻 - N 分)
- 取り消したいときはユーザに「該当ファイルを削除してね」と案内する
- 予定取得手段は Companion / ユーザ任意 (MCP `mcp__Google-Calendar__*` 等を使う場合は別途設定)

### 有効化方法

[voicevox.md の機能宣言チェーン](./voicevox.md#有効化方法-companion-instructionsmd) と同じ仕組みで、各 Companion の `.aidea/claude/companions/<index>/instructions.md` 冒頭で `.aidea/claude/remind.md` を参照することで有効化する。

```markdown
.aidea/claude/aidea.md と .aidea/claude/speech.md と .aidea/claude/remind.md を読んで従ってね
```

リマインド機能を使わない Companion は参照行から `remind.md` を外せばよい。

---

## キャンセル

リマインドのキャンセルは **ファイル削除** で行う。専用のコマンドや状態ファイルは持たない。

- ユーザが Finder / シェルで該当 `remind-*.txt` を削除する
- Companion に「さっきのリマインドキャンセルして」と依頼すれば Companion が `rm` 相当の操作で削除する
- Aidea (RemindScheduler) は FSEvents の削除イベントを検知し、登録済みタイマーを破棄する

---

## Aidea 側のコンポーネント

| コンポーネント | 責務 |
|---|---|
| **RemindWatcher** | `.aidea/backchannels/<0..8>/remind-{YYYYMMDDTHHmmss}.txt` の FSEvents 再帰監視。パターン検証 (厳密な正規表現) を行い、適格なファイルを RemindScheduler に渡す。起動時スキャンも担当する |
| **RemindScheduler** | 検知ファイルのトリガ時刻まで待機し、時刻到達時に SpeechQueue へ投入してから `.fired` リネームを行う。ファイル削除イベントで該当タイマーを破棄する |
| **SpeechQueue** | 既存。VOICEVOX 合成 → AVAudioPlayer 再生。リマインド由来か speech 由来かは区別せず、`companionIndex` 込みで投入される |

実装ファイルの配置は `Services/Backchannel/Remind/` (Speech / Handoff / Output と同じレイアウト)。

---

## エラーハンドリング

| 状態 | 挙動 |
|------|------|
| ファイル名のタイムスタンプがパース不能 | 警告ログ、ファイルは放置 (`.fired` にもしない) |
| トリガ時刻が過去 (起動時スキャン時など) | 警告ログ、`.fired` にリネーム、読み上げはしない |
| ファイル内容が空 | 警告ログ、`.fired` にリネーム、読み上げはしない |
| 読み上げ中に Aidea 終了 | 中断 (SpeechQueue が処理中だった分はキャンセル)。ファイルは `.fired` 状態 |
| トリガ時刻直前に Aidea 終了 | タイマー破棄。次回起動時の scan で「過去のリマインド」として `.fired` にされる (取りこぼし) |
| リマインド機能 OFF (`RemindState.isEnabled == false`) | `RemindWatcher` 停止 + `RemindScheduler` のタイマー全破棄。発火しない。ファイルはそのまま (`.fired` リネームもしない)。ON 復帰時に再スキャンで取り込み |
| 読み上げ機能 OFF (`SpeechState.isEnabled == false`) | `RemindScheduler` から `SpeechQueue` への投入は通常どおり行うが、`SpeechQueue` 側で再生がスキップされる ([voicevox.md の OFF 中の挙動](./voicevox.md#off-中の挙動) と同じ経路)。リマインドのタイマー発火自体は止めない |

---

## 境界

### Always

- ファイル名のタイムスタンプは Aidea / Companion のシステムローカルタイムゾーンで解釈する
- 発火後はファイルを `.fired` リネームする (削除しない、ADR 0024)
- `<companion-index>` は `0..8` の整数のみ有効。それ以外のパスは警告ログのみで無視
- 監視は FSEvents で再帰的に行い、起動時に既存ファイルもスキャンする
- 読み上げ経路は SpeechQueue に統一する (リマインド専用の再生パスを持たない)
- リマインドファイルは書き出し元 Companion の `companion-index` ディレクトリに置き、その Companion として読み上げる (表情・読み上げ中インジケータも同じ扱い)
- ヘッダ常駐 UI には常に「次の最初の予定」1 件 (= `pendingReminds` 先頭) を表示し、空のときは「（予定なし）」、機能 OFF 時は「（停止中）」を表示する
- リマインド機能 ON/OFF の状態変更は `RemindState.toggle()` を経由する (UI トグルから直接 `isEnabled` を書き換えない)

### Never

- Aidea は Google Calendar 等の外部スケジュール元を直接参照しない (Companion 任せ)
- Aidea から cron / launchd 等の外部スケジューラを設定しない (発火点は Aidea プロセス内)
- 発火後のファイルを削除しない (`.fired` リネームのみ)
- パース不能ファイルを勝手に削除・修復しない (ログのみ)
- 過去タイムスタンプのファイルを読み上げない (`.fired` リネームでスキップ)
- 同一トリガ時刻のファイルを重複検知で二重再生しない (FSEvents 検知時に `.fired` 済みファイルかを判定し、既に `.fired` ならスキップ)
- リマインド機能 ON/OFF 状態を `workspace.json` に保存しない (起動時は常に ON、ランタイム情報のみ)
- Popover の表示状態を永続化しない (再起動時は常に閉じた状態)

---

## UI: RemindView (ヘッダ常駐)

### 配置

`WidgetView` の `HStack` 内、`QuickMemoButton` の左隣に追加する。

```
WidgetView
└─ HStack
   ├─ RemindView         ← 今回追加 (カレンダーアイコン + 次予定テキスト)
   ├─ QuickMemoButton    (✏️ クイックメモ)
   └─ TimerView          (ポモドーロ)
```

[../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の AppHeaderView 階層図も同期更新する。

### ヘッダ表示要素

カレンダーアイコン + 「次の最初の予定」1 件をテキストで横並び表示する。

| 要素 | 内容 |
|---|---|
| アイコン | `calendar.badge.clock` SF Symbol。クリックで Popover を開く |
| ラベル | 「次の最初の予定」の `HH:mm` + 本文プレビュー (speaker ID 行を除いた残り、概ね先頭 16〜20 文字。溢れたら `…`) |
| 空状態 | 未発火の予定が 1 件も無い場合は **「（予定なし）」** とラベル表示 (グレー) |
| 機能 OFF 時 | 「（停止中）」と表示 (グレー) |

「次の最初の予定」とは、`RemindScheduler` の保持する未発火タイマーのうち、トリガ時刻が現在時刻より未来かつ最も近い 1 件。

ヘッダ全域 (アイコン + ラベル) を 1 つのクリック領域とし、どこを押しても Popover が開く。

### Popover: RemindPopoverView

クイックメモ入力 popover と同じスタイル (`.popover` 装飾) で表示する。

```
┌─ RemindPopoverView ─────────────────────┐
│  リマインド一覧                          │
│                                         │
│  ┌─ 未発火リスト (トリガ時刻昇順) ───────┐ │
│  │ 14:00 打ち合わせの 1 分前リマイ  [✕] │ │
│  │ 16:00 コードレビュー直前        [✕] │ │
│  │                                    │ │
│  │ (空のとき「予定なし」と表示)         │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ─────────────────────────────────────  │
│  リマインド機能              [ON / OFF] │
└─────────────────────────────────────────┘
```

| 要素 | 内容 |
|---|---|
| タイトル | 「リマインド一覧」 |
| 一覧 | 未発火 (`.fired.txt` でない) かつ未来トリガの `remind-*.txt` をトリガ時刻昇順で全件表示 |
| 各行 | `HH:mm` (トリガ時刻) + 本文プレビュー + 削除ボタン (`✕`) |
| 削除ボタン | クリックで該当 `remind-*.txt` を即時削除 (キャンセル相当)。`RemindScheduler` が FSEvents の削除イベントを受けてタイマー破棄、一覧からも除外される |
| 空状態 | リスト領域に「予定なし」と表示 |
| 機能トグル | Popover 下部にリマインド機能 ON/OFF スイッチを配置 |

- Popover 幅: 約 320pt (QuickMemo の 300pt より少し広い目安)
- ESC で閉じる (`.cancelAction` のキーボードショートカット)

### リマインド機能 ON/OFF (Popover 内トグル)

リマインド機能全体の ON/OFF を切り替えるスイッチ。SpeechState の読み上げトグルと同じ「一時オフ」用途。

| 状態 | 挙動 |
|------|------|
| **ON** (デフォルト) | `RemindWatcher` が FSEvents 監視と起動時スキャンを実行。`RemindScheduler` がトリガ時刻に発火する |
| **OFF** | `RemindScheduler` の全タイマーを破棄。`RemindWatcher` の FSEvents 監視を停止。ヘッダ上ラベルは「（停止中）」と表示 |

#### OFF 中の挙動

- **Aidea 側**: タイマー破棄 + FSEvents 停止。発火しない
- **Companion 側**: 通常どおり `remind-*.txt` を書き出してよい (制限なし)。OFF 中に書かれたファイルは ON 復帰時の再スキャンで取り込まれる
- **ON 復帰時**: 起動時スキャンと同じロジックで `.aidea/backchannels/<0..8>/` を再スキャンし、未来トリガを再登録する

#### 永続化

- ON/OFF 状態は **永続化しない** (`workspace.json` に保存しない)
- アプリ再起動時は常に ON に戻る (`SpeechState` の読み上げトグルと同じ方針)

### 状態管理 (RemindState)

| プロパティ | 用途 |
|---|---|
| `pendingReminds` | 未発火・未来トリガのエントリ一覧 (トリガ時刻昇順)。各エントリは Companion index / トリガ時刻 / プレビュー文字列 / ファイル URL を保持 |
| `isPopoverPresented` | Popover の開閉 |
| `isEnabled` | リマインド機能 ON/OFF |
| `nextPending` (computed) | `pendingReminds` の先頭 1 件 (ヘッダ表示用、空なら nil) |

`pendingReminds` は `RemindWatcher` / `RemindScheduler` の状態と一方向に同期する (ファイル追加 / 削除 / 発火 / 起動時スキャン / OFF→ON 切替のタイミングで更新)。

### キー操作

- Popover 内: ESC で閉じる
- 専用グローバルショートカットは **設けない** (初版)

### 関連 UI コンポーネント (Aidea 側)

| コンポーネント | 責務 |
|---|---|
| `RemindView` | ヘッダ常駐ビュー。アイコン + 次予定テキストを表示。クリックで Popover を開く |
| `RemindPopoverView` | Popover 本体。未発火リスト + ON/OFF トグルを表示 |
| `RemindRowView` | Popover 一覧 1 行 (`HH:mm` + 本文プレビュー + 削除ボタン) |
| `RemindState` | 上記プロパティを公開。`RemindWatcher` / `RemindScheduler` から更新される |

Backchannel ドメイン (`RemindWatcher` / `RemindScheduler`) と UI コンポーネント (`RemindView` / `RemindPopoverView` / `RemindRowView`) は別レイヤに分離し、`RemindState` がその橋渡しを担う。

---

## 関連ドキュメント

- [backchannel.md](./backchannel.md) — Backchannel 全体の設計原則
- [voicevox.md](./voicevox.md) — speech ファイルの読み上げ実装 (本仕様の発火経路と共通)
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/` 配下の永続化仕様
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — AppHeaderView 階層図 (RemindView 配置)
- [../widgets/README.md](../widgets/README.md) — Widgets UI 配置原則
- [../widgets/quick-memo.md](../widgets/quick-memo.md) — Popover 装飾のリファレンス実装
- [../../decisions/0024-backchannel-per-companion-archive.md](../../decisions/0024-backchannel-per-companion-archive.md) — Companion 別保管と履歴保全
