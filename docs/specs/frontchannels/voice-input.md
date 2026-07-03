---
title: 音声入力 (Voice Input)
description: AppHeader のマイクボタンから音声入力ダイアログを開き、アクティブな Claude セッションへテキストを送信する frontchannel 入力経路
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
last_updated: 2026-05-17
---

# 音声入力 (Voice Input)

AppHeader のマイクボタンを押すと、テキスト入力ダイアログが開きフォーカスが当たる。
ユーザは macOS Dictation で音声入力し、OK で確定するとアクティブな Claude セッションへテキストが送信される。

[Frontchannel](./frontchannel.md) (Aidea → Claude) の入力源の 1 つ。
タイピング・[Recommend モード](../companions/recommend-mode.md) と並ぶ第 3 の入力経路。

---

## 概要

| 項目 | 内容 |
|---|---|
| 起動 UI | `AppHeaderView` 内の 🎤 ボタン (`CompanionView` の直右、`speechToggleButton` の隣) |
| ダイアログ形式 | `NSAlert` + `NSTextField` (`FileNameInputDialog` と同じパターン) |
| 入力手段 | macOS Dictation (NSTextField 標準サポート) + 通常のキーボード入力も可 |
| 送信先 | `SessionRegistry.activeSessionID` が指す Claude セッション |
| 非アクティブ時の挙動 | アクティブセッションが Claude でない場合はボタン disabled |
| 改行付与 | 送信時に `"\r"` を自動付加 ([frontchannel.md](./frontchannel.md) と同じ) |
| 永続化 | なし (ダイアログ閉鎖で入力テキスト破棄) |

---

## UI 仕様

### ヘッダへの配置

`AppHeaderView` の `HStack` 内、`speechToggleButton` の**直右**に `voiceInputButton` を配置する。
`Spacer` より左 (= 左端寄せ) で、`WidgetView` には属さない。

```
AppHeaderView
└─ HStack(spacing: 8)
   ├─ CompanionView            ※既存
   ├─ speechToggleButton       ※既存 (backchannel 制御: 読み上げ ON/OFF)
   ├─ voiceInputButton         ※今回追加 (frontchannel 制御: 音声入力起動)
   ├─ Spacer                   ※既存
   └─ WidgetView               ※既存
```

**配置の意図**: `speechToggleButton` (backchannel = Claude → ユーザの音声出力制御) と対称に、`voiceInputButton` (frontchannel = ユーザ → Claude の音声入力起動) を並べる。両者ともセッション横断のグローバル制御。

### ボタン仕様

| 項目 | 内容 |
|---|---|
| アイコン | SF Symbol `mic.fill` (アクティブ Claude あり) / `mic.slash.fill` (disabled) |
| サイズ | `frame(width: 32, height: 32)` (`speechToggleButton` と統一) |
| ボタンスタイル | `.buttonStyle(.plain)` |
| ツールチップ | `.help("音声入力 (アクティブな Claude セッションへ送信)")` |
| disabled 条件 | アクティブセッションが Claude セッションでない or 未起動 |

### ダイアログレイアウト

```
┌─ 音声入力 ──────────────────────────┐
│  [NSTextField (1 行入力)]            │
│                                      │
│         [キャンセル]      [送信]      │
└──────────────────────────────────────┘
```

- ベース: `NSAlert` (`FileNameInputDialog` と同じ実装パターン)
- 送信先コンパニオン名をタイトル/メッセージに表示する (例: `main-chan に送信`)
- **アイコン**: `NSAlert.icon` を送信先コンパニオンの thumbnail (`CompanionIconPresets.thumbnailIcon(for: companion.icon)` → `NSImage(named:)`) に差し替える。
  どのコンパニオンへ送られるかを視覚的に確認できるようにし、CompanionView のアイコン (idle/inactive と同じバリアント) と整合させる。
  該当 CompanionConfig が解決できないときはアイコン未指定 (アプリアイコンが表示される)。
- 入力欄: `NSTextField` を `accessoryView` に配置
  - 幅: 360pt 程度
  - **初期フォーカス**: `alert.window.makeFirstResponder(textField)` で textField に当てる
  - プレースホルダ: `"音声で入力するか、テキストを入力してください"`
- ボタン:
  - **送信** (右、デフォルト): Enter で発火 (NSAlert first button 自動割当)。空文字時は disabled
  - **キャンセル** (左): `keyEquivalent = "\u{1b}"` で Esc 発火

[../window/dialogs.md](../window/dialogs.md) のキー割当ルールに従う。

### キー操作

| キー | 動作 |
|---|---|
| **⌘ ⌥ V** | (グローバル) 音声入力ダイアログを開く。ボタンと同条件で、アクティブセッションが Claude のときのみ有効 |
| **Enter** | (ダイアログ内) 送信 (空文字時は無効) |
| **Esc** | (ダイアログ内) キャンセル (入力破棄) |
| ユーザの Dictation ショートカット | (ダイアログ内) macOS Dictation 起動 (NSTextField が標準サポート) |

#### グローバルショートカット (⌘ ⌥ V)

`AideaApp.body.commands` の「Aidea」メニュー直下の項目として実装する (issue #130)。
([../window/shortcuts.md](../window/shortcuts.md) の「音声入力」セクションと同期)

- **キー選定理由**: V = Voice の連想で覚えやすく、`⌘ ⌥` 系の既存ショートカット (ツール切替・タイマー) と修飾キー体系が揃う。`⌘ ⌥ V` は未使用空きキー。
- **有効条件**: `voiceInputButton` の disabled 条件と完全に一致させる (アクティブセッションが Claude セッションのとき有効、そうでなければ disabled)。
- **動作**: ボタン押下と同じ `VoiceInputDialog` を表示する。マイク権限フローやダイアログ仕様はボタン押下時と一切同じ。

### Dictation の自動起動

ダイアログを開いた瞬間に macOS Dictation を**自動 ON にする**。実装は **⌘ ⌥ ⇧ V (Cmd+Option+Shift+V) を CGEvent で 1 度だけ POST** する方式を使う (V の virtual key code は `0x09`)。

- ダイアログを表示し NSTextField にフォーカスを当てたあと、`CGEventPost` で `V` キーの down/up を 1 ペア、修飾フラグ `[.maskCommand, .maskAlternate, .maskShift]` 付きでグローバルイベントタップに送る
- ユーザのシステム設定 (キーボード > 音声入力 (Dictation) > ショートカット) で **「カスタムショートカット → ⌘ ⌥ ⇧ V」** に設定されている前提で動作する
- Aidea 自身のダイアログ起動は ⌘ ⌥ V で、Shift の有無で衝突しないように選んでいる (ダイアログを開く → 中で ⌘ ⌥ ⇧ V を発火 → Dictation 起動)
- ショートカットが変更されている / 無効化されているユーザでは自動 ON が空振りするが、ダイアログ内 NSTextField にフォーカスがあれば**手動で自分のショートカットを押せば Dictation は起動できる**ためフォールバックされる
- 完全な自動起動が必要なら Speech.framework 直接統合を検討するが、本 spec では対象外

#### キーストローク変遷 (なぜ double-tap でなくユニーク 1 回押しか)

| 試行 | キー | 結果 |
|---|---|---|
| 試行 1 | Control キー 2 度押し (`0x3B`, `.maskControl`) | 修飾キーリマップ (Ctrl↔CapsLock 入れ替え) があるユーザで Dictation 検出ロジックに刺さらず空振り |
| 試行 2 | Caps Lock キー 2 度押し (`0x39`, `.maskAlphaShift`) | CGEvent 経路で double-tap の発火タイミングが安定せず、ユーザ環境で起動しなかった |
| 採用 | ⌘ ⌥ ⇧ V を 1 回押し (`0x09`, `[.maskCommand, .maskAlternate, .maskShift]`) | ユニーク修飾キー組合せの 1 回押しなので double-tap 検出窓・toggle 特殊性・リマップ階層の影響を受けず一貫して発火 |

- macOS のキーリマップ (修飾キーを変更) は CGEvent.post の出口 (HID イベントタップ) より**上の階層**で解釈されるため、物理位置依存のキーコード経路は環境依存が出やすい
- ユニーク修飾キー組合せの 1 回押しなら、Dictation のホットキーディスパッチはアプリ非依存のグローバルハンドラに直行するので、リマップや double-tap 検出窓に左右されない
- 引き換えに、ユーザは Dictation ショートカットを「カスタムショートカット → ⌘ ⌥ ⇧ V」へ自分で割り当てる必要がある (一度設定すれば永続)

---

## 動作仕様

### 送信ターゲットの解決

1. `SessionRegistry.activeSessionID` から現在アクティブな Session を取得
2. その Session が `ClaudeSessionState` を保持しているか判定
3. 保持していればその `ClaudeSessionState` を送信先とする
4. していなければボタン disabled (ダイアログ開けない)

セッション横断検索 (例: "最も新しい Claude セッションへ送る") は **行わない**。ユーザが意識しているアクティブセッションだけを対象にする (送信先がブレない)。

### 送信処理

[Handoff](../backchannels/handoff.md) の送信経路と**同じ** `sendMessageWhenReady` を使う。
([frontchannel.md](./frontchannel.md) と handoff の dispatch 実装の標準パターン)

- `sendMessageWhenReady` を使って PTY に送信する。Claude 起動済みなら即送信、未起動なら起動完了後に自動送信する
- 送信前に前後の空白文字を除去する
- 改行は送信側で自動付加 (二重付加しない)
- handoff / recommend と同じ堅牢な送信経路を採用し、Claude 起動状態の変動に追従する
- 送信成功後、ダイアログを閉じる

### 空入力・空白のみ

- 入力テキストが空 or 空白のみのとき、**送信ボタンは disabled**
- リアルタイムバリデーション ([dialogs.md](../window/dialogs.md) のルール): `textDidChangeNotification` で監視
- 送信不可状態で Enter を押しても何も起こらない

### 送信後

- ダイアログを閉じる
- 入力テキストはメモリから破棄 (永続化しない)
- アクティブセッションをユーザが切り替えていない限り、もう一度ボタンを押すと**空のダイアログから始まる**

---

## マイク権限 (TCC)

`Info.plist` に `NSMicrophoneUsageDescription` を**再導入**する。

```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声入力ダイアログでの macOS Dictation 利用にマイクへのアクセスが必要です。Aidea 本体は録音しません。</string>
```

- 初回のマイクボタン押下時に `AVCaptureDevice.requestAccess(for: .audio)` を呼び、TCC ダイアログを発火させる
- ユーザが拒否した場合は、システム設定 (`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`) を開く誘導 alert を表示する。「設定を開く」「キャンセル」の 2 択
- 権限が **未確定 (.notDetermined)** のときはダイアログ表示前に `requestAccess` を完了させてから本体ダイアログへ進む

### Hardened Runtime と entitlements (落とし穴メモ)

Aidea は **App Sandbox は無効** ([CLAUDE.md](../../../CLAUDE.md) の「重要な境界」参照) だが **Hardened Runtime は有効** な構成のため、`Info.plist` の `NSMicrophoneUsageDescription` だけでは TCC にマイク要求が登録されない (`AVCaptureDevice.requestAccess` を呼んでもシステム設定 → プライバシーとセキュリティ → マイク に Aidea が出てこない)。

そのため `Aidea/Aidea/Aidea.entitlements` で以下の entitlement を有効化し、ビルド設定 `CODE_SIGN_ENTITLEMENTS` に明示的に紐付ける必要がある:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

App Sandbox 無効方針と矛盾しない。Hardened Runtime 側のマイク許可フラグであり、App Sandbox の `com.apple.security.app-sandbox = true` を伴わない。

### ADR 0027 (保留) との関係

- ADR [0027: Terminal/Claude セッションでの Dictation 対応を保留](../../decisions/0027-microphone-permission.md) で `NSMicrophoneUsageDescription` を**一度削除した**経緯がある
- ADR 0027 の保留理由は **SwiftTerm 上の Dictation** が動かなかったことであり、`NSTextField` での Dictation は試行 1 で動作確認済み
- 本 spec は SwiftTerm を経由しない**別ルート** (NSAlert + NSTextField) で Dictation を利用する設計なので、ADR 0027 と矛盾しない
- ADR 0027 は「保留」のまま据え置く (SwiftTerm 内 Dictation は別件として後日再開)

---

## 状態管理

`VoiceInputButton` (View) と `VoiceInputDialog` (NSAlert wrapper) のみで完結する。永続化なし。

| 状態 | 保持場所 | 寿命 |
|---|---|---|
| 入力中テキスト | NSTextField の `stringValue` | ダイアログ閉鎖まで |
| マイク権限ステータス | OS の TCC (`AVCaptureDevice.authorizationStatus(for: .audio)`) | OS 管理 |

Aidea 側で TCC のフラグを別途 UserDefaults に複製する必要はない (OS の TCC レイヤがリクエスト済みかを永続化しているため)。

---

## 永続化

入力テキスト・ダイアログ状態・権限フラグはいずれも **Aidea 側では永続化しない**。
[persistence.md](../aspects/persistence.md) への追記は不要。

---

## 影響範囲

| 変更対象 | 更新内容 |
|---|---|
| `AppHeaderView` | 音声入力ボタン追加 |
| `Info.plist` | マイク使用説明文 (`NSMicrophoneUsageDescription`) 追加 |
| Entitlements | `com.apple.security.device.audio-input` を追加 (Hardened Runtime 下でマイク TCC 要求) |
| `VoiceInputButton` (新規) | ボタン本体 |
| `VoiceInputDialog` (新規) | NSAlert + NSTextField ラッパ |
| `AideaApp` | 「Aidea」メニューに音声入力項目を追加し `⌘⌥V` にバインド |
| `MicrophonePermission` (新規復活) | TCC 要求ヘルパ (ADR 0027 で削除したもの) |
| [aspects/view-hierarchy.md](../aspects/view-hierarchy.md) | `AppHeaderView` の階層図に `VoiceInputButton` を追加 |
| [frontchannels/README.md](./README.md) | 本 spec へのリンク追加 |

---

## 不採用案 / 検討した分岐

| 案 | 不採用理由 |
|---|---|
| Speech.framework で独自録音 → 文字起こし | OS の Dictation と二重実装になり責務肥大。まずは macOS Dictation 連携で MVP を作る |
| SwiftTerm 内で直接 Dictation を起動 | ADR 0027 で保留済み。技術的ハードルが高い |
| 音声入力ボタンを `WidgetView` に入れる | speechToggle と対称配置にすべきで、frontchannel 制御は左寄せ (CompanionView 近く) が直感的。WidgetView (右端) は機能群が違う |
| ショートカットを `⌘ ⇧ ⌥ M` (読み上げトグル `⌘ ⌥ M` とペア化) | 修飾 3 つは押下コストが高い。`⌘ ⌥ V` (V=Voice) の方が直感的かつ片手で押せる |
| ショートカットを `⌘ ⇧ M` | macOS の他アプリ (メール送信など) で慣習的に使われがちで衝突しやすい |
| 送信先を選べる UI (アクティブでないコンパニオンへ送る) | 「ユーザが見ている対象に送る」原則を崩すと意図しない送信が起きる。Recommend モードと混同する恐れ |

---

## 関連ドキュメント

- [frontchannel.md](./frontchannel.md) — Aidea → Claude 送信メカニズム (`send(txt:)`)
- [../window/dialogs.md](../window/dialogs.md) — ダイアログ共通規約 (Esc/Enter, リアルタイムバリデーション)
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — `AppHeaderView` の階層
- [../aspects/persistence.md](../aspects/persistence.md) — 永続化データ一覧
- ADR [0027: Terminal/Claude セッションでの Dictation 対応を保留](../../decisions/0027-microphone-permission.md) — 経緯と知見
