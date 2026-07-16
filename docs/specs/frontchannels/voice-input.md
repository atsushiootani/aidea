---
title: 音声入力 (Voice Input)
description: アプリヘッダのマイクボタンから音声入力ダイアログを開き、アクティブな Claude セッションへテキストを送信する frontchannel 入力経路
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/window/dialogs.md
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/window/shortcuts.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# 音声入力 (Voice Input)

アプリヘッダのマイクボタンを押すと、テキスト入力ダイアログが開きフォーカスが当たる。
ユーザは macOS Dictation で音声入力し、OK で確定するとアクティブな Claude セッションへテキストが送信される。

[Frontchannel](./frontchannel.md) (Aidea → Claude) の入力源の 1 つ。
タイピング・[Recommend モード](../companions/recommend-mode.md) と並ぶ第 3 の入力経路。

---

## 概要

| 項目 | 内容 |
|---|---|
| 起動 UI | アプリヘッダ内の 🎤 ボタン (Companion アイコンの直右、読み上げトグルボタンの隣) |
| ダイアログ形式 | ネイティブのアラート + 1 行テキスト入力欄 (ファイル名入力ダイアログと同じパターン) |
| 入力手段 | macOS Dictation (テキスト入力欄が OS 標準でサポート) + 通常のキーボード入力も可 |
| 送信先 | 現在アクティブな Session が指す Claude セッション |
| 非アクティブ時の挙動 | アクティブセッションが Claude でない場合はボタン disabled |
| 改行付与 | 送信時に `"\r"` を自動付加 ([frontchannel.md](./frontchannel.md) と同じ) |
| 永続化 | なし (ダイアログ閉鎖で入力テキスト破棄) |

---

## UI 仕様

### ヘッダへの配置

アプリヘッダの横並び領域で、読み上げトグルボタンの**直右**に音声入力ボタンを配置する。
左端寄せ (スペーサより左) で、右端のウィジェット群には属さない。

```
アプリヘッダ (左 → 右)
├─ Companion アイコン群        ※既存
├─ 読み上げトグルボタン         ※既存 (backchannel 制御: 読み上げ ON/OFF)
├─ 音声入力ボタン              ※今回追加 (frontchannel 制御: 音声入力起動)
├─ (スペーサ)                  ※既存
└─ ウィジェット群              ※既存
```

**配置の意図**: 読み上げトグルボタン (backchannel = Claude → ユーザの音声出力制御) と対称に、音声入力ボタン (frontchannel = ユーザ → Claude の音声入力起動) を並べる。両者ともセッション横断のグローバル制御。

### ボタン仕様

| 項目 | 内容 |
|---|---|
| アイコン | SF Symbols のマイク (アクティブ Claude あり) / 斜線付きマイク (disabled) |
| サイズ | 32×32pt (読み上げトグルボタンと統一) |
| 見た目 | 装飾なしのプレーンなボタン |
| ツールチップ | 「音声入力 (アクティブな Claude セッションへ送信)」 |
| disabled 条件 | アクティブセッションが Claude セッションでない or 未起動 |

### ダイアログレイアウト

```
┌─ 音声入力 ──────────────────────────┐
│  [テキスト入力欄 (1 行)]              │
│                                      │
│         [キャンセル]      [送信]      │
└──────────────────────────────────────┘
```

- ベース: ネイティブのアラート (ファイル名入力ダイアログと同じ実装パターン)
- 送信先コンパニオン名をタイトル/メッセージに表示する (例: `main-chan に送信`)
- **アイコン**: アラートのアイコンを送信先コンパニオンの thumbnail 画像に差し替える。
  どのコンパニオンへ送られるかを視覚的に確認できるようにし、Companion アイコン (idle/inactive と同じバリアント) と整合させる。
  該当コンパニオン設定が解決できないときはアイコン未指定 (アプリアイコンが表示される)。
- 入力欄: 1 行テキスト入力欄をアラート内に配置
  - 幅: 360pt 程度
  - **初期フォーカス**: 表示と同時に入力欄へフォーカスを当てる
  - プレースホルダ: `"音声で入力するか、テキストを入力してください"`
- ボタン:
  - **送信** (右、デフォルト): Enter で発火。空文字時は disabled
  - **キャンセル** (左): Esc で発火

[../window/dialogs.md](../window/dialogs.md) のキー割当ルールに従う。

### キー操作

| キー | 動作 |
|---|---|
| **⌘ ⌥ V** | (グローバル) 音声入力ダイアログを開く。ボタンと同条件で、アクティブセッションが Claude のときのみ有効 |
| **Enter** | (ダイアログ内) 送信 (空文字時は無効) |
| **Esc** | (ダイアログ内) キャンセル (入力破棄) |
| ユーザの Dictation ショートカット | (ダイアログ内) macOS Dictation 起動 (テキスト入力欄が標準サポート) |

#### グローバルショートカット (⌘ ⌥ V)

アプリの「Aidea」メニュー直下の項目として実装する (issue #130)。
([../window/shortcuts.md](../window/shortcuts.md) の「音声入力」セクションと同期)

- **キー選定理由**: V = Voice の連想で覚えやすく、`⌘ ⌥` 系の既存ショートカット (ツール切替・タイマー) と修飾キー体系が揃う。`⌘ ⌥ V` は未使用空きキー。
- **有効条件**: 音声入力ボタンの disabled 条件と完全に一致させる (アクティブセッションが Claude セッションのとき有効、そうでなければ disabled)。
- **動作**: ボタン押下と同じ音声入力ダイアログを表示する。マイク権限フローやダイアログ仕様はボタン押下時と一切同じ。

### Dictation の自動起動

ダイアログを開いた瞬間に macOS Dictation を**自動 ON にする**。実現方法は **⌘ ⌥ ⇧ V (Cmd+Option+Shift+V) のキーイベントを OS のグローバルイベント経路に 1 度だけ合成送出**する方式。

- ダイアログを表示し入力欄にフォーカスを当てたあと、`⌘ ⌥ ⇧` 修飾付きの `V` キー down/up を 1 ペア合成してグローバルに送る
- ユーザのシステム設定 (キーボード > 音声入力 (Dictation) > ショートカット) で **「カスタムショートカット → ⌘ ⌥ ⇧ V」** に設定されている前提で動作する
- Aidea 自身のダイアログ起動は ⌘ ⌥ V で、Shift の有無で衝突しないように選んでいる (ダイアログを開く → 中で ⌘ ⌥ ⇧ V を発火 → Dictation 起動)
- ショートカットが変更されている / 無効化されているユーザでは自動 ON が空振りするが、ダイアログ内の入力欄にフォーカスがあれば**手動で自分のショートカットを押せば Dictation は起動できる**ためフォールバックされる
- 完全な自動起動が必要なら Speech.framework 直接統合を検討するが、本 spec では対象外

#### キーストローク変遷 (なぜ double-tap でなくユニーク 1 回押しか)

| 試行 | キー | 結果 |
|---|---|---|
| 試行 1 | Control キー 2 度押し | 修飾キーリマップ (Ctrl↔CapsLock 入れ替え) があるユーザで Dictation 検出ロジックに刺さらず空振り |
| 試行 2 | Caps Lock キー 2 度押し | キーイベント合成経路で double-tap の発火タイミングが安定せず、ユーザ環境で起動しなかった |
| 採用 | ⌘ ⌥ ⇧ V を 1 回押し | ユニーク修飾キー組合せの 1 回押しなので double-tap 検出窓・toggle 特殊性・リマップ階層の影響を受けず一貫して発火 |

- macOS のキーリマップ (修飾キーを変更) はイベント合成の出口より**上の階層**で解釈されるため、物理位置依存のキーコード経路は環境依存が出やすい
- ユニーク修飾キー組合せの 1 回押しなら、Dictation のホットキーディスパッチはアプリ非依存のグローバルハンドラに直行するので、リマップや double-tap 検出窓に左右されない
- 引き換えに、ユーザは Dictation ショートカットを「カスタムショートカット → ⌘ ⌥ ⇧ V」へ自分で割り当てる必要がある (一度設定すれば永続)

---

## 動作仕様

### 送信ターゲットの解決

1. 現在アクティブな Session を取得
2. その Session が Claude セッションかどうか判定
3. Claude セッションならそれを送信先とする
4. そうでなければボタン disabled (ダイアログ開けない)

セッション横断検索 (例: "最も新しい Claude セッションへ送る") は **行わない**。ユーザが意識しているアクティブセッションだけを対象にする (送信先がブレない)。

### 送信処理

[Handoff](../backchannels/handoff.md) と**同じ**「[受付可能になってから送る送信](./frontchannel.md#送信メカニズム)」を使う。

- Claude 起動済みなら即送信、未起動なら起動完了 (受付可能) 後に自動送信する
- 送信前に前後の空白文字を除去する
- 改行は送信側で自動付加 (二重付加しない)
- handoff / recommend と同じ堅牢な送信経路を採用し、Claude 起動状態の変動に追従する
- 送信成功後、ダイアログを閉じる

### 空入力・空白のみ

- 入力テキストが空 or 空白のみのとき、**送信ボタンは disabled**
- リアルタイムバリデーション ([dialogs.md](../window/dialogs.md) のルール): 入力テキストの変更を監視して即時反映する
- 送信不可状態で Enter を押しても何も起こらない

### 送信後

- ダイアログを閉じる
- 入力テキストはメモリから破棄 (永続化しない)
- アクティブセッションをユーザが切り替えていない限り、もう一度ボタンを押すと**空のダイアログから始まる**

---

## マイク権限 (TCC)

アプリのマイク使用説明文 (`NSMicrophoneUsageDescription`) を**再導入**する。

> 音声入力ダイアログでの macOS Dictation 利用にマイクへのアクセスが必要です。Aidea 本体は録音しません。

- 初回のマイクボタン押下時に OS のマイク権限要求を呼び、TCC ダイアログを発火させる
- ユーザが拒否した場合は、システム設定のマイクプライバシー画面 (`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`) を開く誘導 alert を表示する。「設定を開く」「キャンセル」の 2 択
- 権限が **未確定** のときはダイアログ表示前に権限要求を完了させてから本体ダイアログへ進む

### Hardened Runtime と entitlements (落とし穴メモ)

Aidea は **App Sandbox は無効** ([CLAUDE.md](../../../CLAUDE.md) の「重要な境界」参照) だが **Hardened Runtime は有効** な構成のため、マイク使用説明文だけでは TCC にマイク要求が登録されない (権限要求を呼んでもシステム設定 → プライバシーとセキュリティ → マイク に Aidea が出てこない)。

そのため entitlements で `com.apple.security.device.audio-input` を有効化し、ビルド設定で entitlements ファイルをターゲットに明示的に紐付ける必要がある。

App Sandbox 無効方針と矛盾しない。Hardened Runtime 側のマイク許可フラグであり、App Sandbox 本体の有効化を伴わない。

### ADR 0027 (保留) との関係

- ADR [0027: Terminal/Claude セッションでの Dictation 対応を保留](../../decisions/0027-microphone-permission.md) でマイク使用説明文を**一度削除した**経緯がある
- ADR 0027 の保留理由は **SwiftTerm 上の Dictation** が動かなかったことであり、ネイティブのテキスト入力欄での Dictation は試行 1 で動作確認済み
- 本 spec は SwiftTerm を経由しない**別ルート** (アラート + テキスト入力欄) で Dictation を利用する設計なので、ADR 0027 と矛盾しない
- ADR 0027 は「保留」のまま据え置く (SwiftTerm 内 Dictation は別件として後日再開)

---

## 状態管理

音声入力ボタンとダイアログの中だけで完結する。永続化なし。

| 状態 | 保持場所 | 寿命 |
|---|---|---|
| 入力中テキスト | ダイアログの入力欄 | ダイアログ閉鎖まで |
| マイク権限ステータス | OS の TCC | OS 管理 |

Aidea 側で TCC のフラグを別途複製・保存する必要はない (OS の TCC レイヤがリクエスト済みかを永続化しているため)。

---

## 永続化

入力テキスト・ダイアログ状態・権限フラグはいずれも **Aidea 側では永続化しない**。
[persistence.md](../aspects/persistence.md) への追記は不要。

---

## 影響範囲

| 変更対象 | 更新内容 |
|---|---|
| アプリヘッダ | 音声入力ボタン追加 |
| マイク使用説明文 | `NSMicrophoneUsageDescription` 追加 |
| Entitlements | `com.apple.security.device.audio-input` を追加 (Hardened Runtime 下でマイク TCC 要求) |
| 音声入力ボタン (新規) | ボタン本体 |
| 音声入力ダイアログ (新規) | アラート + テキスト入力欄のラッパ |
| アプリメニュー | 「Aidea」メニューに音声入力項目を追加し `⌘⌥V` にバインド |
| マイク権限要求ヘルパ (新規復活) | TCC 要求 (ADR 0027 で削除したもの) |
| [aspects/view-hierarchy.md](../aspects/view-hierarchy.md) | アプリヘッダの階層図に音声入力ボタンを追加 |
| [frontchannels/README.md](./README.md) | 本 spec へのリンク追加 |

---

## 不採用案 / 検討した分岐

| 案 | 不採用理由 |
|---|---|
| Speech.framework で独自録音 → 文字起こし | OS の Dictation と二重実装になり責務肥大。まずは macOS Dictation 連携で MVP を作る |
| SwiftTerm 内で直接 Dictation を起動 | ADR 0027 で保留済み。技術的ハードルが高い |
| 音声入力ボタンをウィジェット群に入れる | 読み上げトグルと対称配置にすべきで、frontchannel 制御は左寄せ (Companion アイコン近く) が直感的。ウィジェット群 (右端) は機能群が違う |
| ショートカットを `⌘ ⇧ ⌥ M` (読み上げトグル `⌘ ⌥ M` とペア化) | 修飾 3 つは押下コストが高い。`⌘ ⌥ V` (V=Voice) の方が直感的かつ片手で押せる |
| ショートカットを `⌘ ⇧ M` | macOS の他アプリ (メール送信など) で慣習的に使われがちで衝突しやすい |
| 送信先を選べる UI (アクティブでないコンパニオンへ送る) | 「ユーザが見ている対象に送る」原則を崩すと意図しない送信が起きる。Recommend モードと混同する恐れ |

---

## 関連ドキュメント

- [frontchannel.md](./frontchannel.md) — Aidea → Claude 送信メカニズム
- [../window/dialogs.md](../window/dialogs.md) — ダイアログ共通規約 (Esc/Enter, リアルタイムバリデーション)
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — アプリヘッダの階層
- [../aspects/persistence.md](../aspects/persistence.md) — 永続化データ一覧
- ADR [0027: Terminal/Claude セッションでの Dictation 対応を保留](../../decisions/0027-microphone-permission.md) — 経緯と知見
