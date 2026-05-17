---
title: "0026: Terminal/Claude セッションでの Dictation 対応を保留"
description: SwiftTerm ベースのターミナル View で macOS Dictation を有効化する試行と、複数アプローチが効果不十分だったため一旦保留とする決定の記録
status: 保留
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-17
---

# 0026: Terminal/Claude セッションでの Dictation 対応を保留

**日付**: 2026-05-17

## 背景 (Why now?)

Aidea のターミナル (SwiftTerm) で動作する `claude` CLI 等に対して、macOS 標準の音声入力 (Dictation) が反応しない問題があった。同じ Mac 上の Terminal.app / Claude.app / Chrome 等の他アプリでは Dictation が動作する。

ユーザ環境ではマイク入力ショートカットが **Ctrl 2 度押し** に割り当てられており、同じショートカットでファイル名入力ダイアログ (`NSTextField`) では有効効果音と共に音声入力が機能するが、ターミナル / Claude セッション (SwiftTerm の `LocalProcessTerminalView` 経由) では Dictation 起動時に**無効効果音**が鳴り、音声入力が受け付けられない状態が継続した。

「システム設定 → プライバシーとセキュリティ → マイク」では当初 Aidea が許可リストに**登場すらしていない** (Audacity / Claude / GarageBand / Chrome / Notion / Slack / Steam / zoom / ターミナル等は存在) ことから、まずは Aidea プロセス自体が macOS から「マイク使用候補」と見なされていないという仮説で対応を開始した。

## 試行した対応 (すべて効果不十分)

### 試行 1: TCC マイク権限の宣言と取得

`Info.plist` に `NSMicrophoneUsageDescription` を追加し、起動時に `AVCaptureDevice.requestAccess(for: .audio)` を呼んで TCC ダイアログを発火させる。

```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声入力 (macOS の Dictation や Aidea のターミナルから起動した CLI ツール) が動作するためにマイクへのアクセスが必要です。Aidea 本体は録音しません。</string>
```

```swift
// 起動時に一度だけ呼ぶ
AVCaptureDevice.requestAccess(for: .audio) { _ in /* 結果は無視 */ }
```

- 効果: `NSTextField` ベースのダイアログ (Filer のファイル名入力等) では Dictation が機能するようになった
- 限界: SwiftTerm の `TerminalView` 内では Dictation が依然として無効効果音を鳴らし続けた

### 試行 2: AX role / element の override

`PersistentTerminalView` で以下を override:

```swift
override func accessibilityRole() -> NSAccessibility.Role? { .textArea }
override func isAccessibilityElement() -> Bool { true }
```

Accessibility Inspector で確認すると AX tree 上は `AXTextArea` として認識され、`Value` (PTY バッファ全文) や `Number Of Characters` も AppKit の自動補完で取得可能になった。しかし Dictation の挙動は変わらず。

### 試行 3: AX focus chain の貫通

SwiftUI の `NSHostingView` (AXGroup) が `PersistentTerminalView` の親階層に挟まり、Dictation の focus 探索が AXGroup 段で止まる仮説のもと、以下を追加:

```swift
func accessibilityFocusedUIElement() -> Any? { self }
override func isAccessibilityFocused() -> Bool { window?.firstResponder === self }
```

挙動変わらず。

### 試行 4: NSTextInputClient geometry 補完 (macOS 14+ 仕様)

WWDC23 で macOS 14 以降の Dictation は `NSTextInputClient` に新しい geometry プロパティを要求するようになった。SwiftTerm の実装は不完全で、特に `firstRect(forCharacterRange:)` は caretView の box (= 1 セル幅) を返してしまうため、Dictation のゼロ幅 caret rect 期待と齟齬が生じる。[cmux PR #1410](https://github.com/manaflow-ai/cmux/pull/1410) (Ghostty による同種解決) を参考に補完を実装:

- `firstRect(forCharacterRange:)`: `length == 0` のとき `width = 0` に塗りつぶす
- `characterIndex(for:)`: `NSNotFound` 返却 → `selectedRange().location` に差し替え
- `windowLevel()`: `window?.level.rawValue` を返す
- `documentVisibleRect` (macOS 14+): 画面座標の `visibleRect`
- `unionRectInVisibleSelectedRange` (macOS 14+): caret 位置の rect
- `inputContext?.invalidateCharacterCoordinates()` を `layout` / `setFrameSize` / `viewDidMoveToWindow` で呼び出し

挙動変わらず。

## 確定できなかった真の原因

以下のいずれか (または組み合わせ) が考えられるが、本セッションでは特定に至らなかった:

1. **ユーザショートカットの正体未確認**: Ctrl 2 度押しが macOS Dictation なのか Voice Control なのかをシステム設定で確認できていない。Voice Control は AX 要件が異なるため、もし Voice Control なら本試行群は的外れの可能性がある。
2. **SwiftTerm の subview tree が AX/Input chain を妨害**: `TerminalView` は `caretView` 等の subview を持ち、これが AX `accessibilityFocusedUIElement` の自然解決を妨げている可能性。
3. **NSTextInputClient で追加の未実装メソッドが必要**: `attributedString()` (macOS 14+) / `attributedSubstring(forProposedRange:)` の非 nil 返却が必要な可能性。cmux PR #1410 では実装済みだが Aidea 側では未対応。SwiftTerm 側の `markedRange()` / `hasMarkedText()` / `validAttributesForMarkedText()` も常に空/false 返却で不完全。
4. **SwiftUI WindowGroup 由来の AppKitWindow 固有挙動**: AppKit 単体の `NSWindow` ではなく SwiftUI 経由の窓構造が `accessibilityFocusedUIElement` 解決に独自介入している可能性。
5. **Hardened Runtime + Audio Input entitlement**: `ENABLE_HARDENED_RUNTIME = YES` だが `com.apple.security.device.audio-input` entitlement は付与していない。Sandbox 無効下では理論上不要だが Dictation 経路では別判定の可能性がある。

## 決定

Terminal / Claude セッションでの Dictation 対応を一旦**保留** (Status: 保留)。実装中の変更 (`Info.plist` への `NSMicrophoneUsageDescription` 追加、`MicrophonePermission` ヘルパ、`PersistentTerminalView` の AX / NSTextInputClient override) を**全て破棄**してブランチを元に戻し、本 ADR に試行と知見だけを残す。

「ファイル名ダイアログでは Dictation 動く」という副次効果も同時に取り下げる。中途半端な状態で main にコードを残すと、再開時に「どこまで対応済みか」「なぜ動かないか」の調査が複雑化するため。

## 再開条件 / 次回アクション

再開する際は以下のいずれかから着手するのが効率的:

1. **ショートカットの正体確認**: システム設定 > キーボード > Dictation Shortcut と システム設定 > アクセシビリティ > Voice Control を確認し、Ctrl 2 度押しがどちらに紐付いているかを特定する
2. **Console.app で `corespeechd` のログ採取**: `log stream --predicate 'process == "corespeechd"'` を流しながら Aidea ターミナル上で Ctrl 2 度押しすると、Dictation サービスが拒否した理由が出力される可能性が高い
3. **同一ウィンドウ内に純粋な `NSTextView` を 1 つ置いて切り分け**: SwiftTerm 由来の問題か Aidea / SwiftUI 起因かを判別できる
4. **SwiftTerm の残存補完項目を追加**: `attributedString()` / `attributedSubstring(forProposedRange:)` / `markedRange()` / `hasMarkedText()` 等を Aidea 側で override し、cmux PR #1410 と完全一致させた状態で再試行
5. **SwiftTerm を fork して NSTextInputClient / NSAccessibility を完全実装**: 最終手段。upstream に PR を投げる選択肢も含めて検討
6. **外部音声入力ツール (SuperWhisper / Whisper.cpp 等) との連携で代替**: 本体での Dictation 動作を諦めて回避する方針も視野に入れる

## トレードオフ

- **当面 Dictation は使えない**: ターミナル / Claude セッション内では macOS の音声入力ができない状態が続く。ファイル名ダイアログでも動かなくなる (試行 1 を取り下げるため)
- **外部ツールへの依存**: 音声入力が必要な場合は SuperWhisper や Whisper.cpp など外部ツールを別途利用する形になる
- **本 ADR を残す意義**: 試行錯誤の知見を失わず、再開時に同じ調査を繰り返さないようにする

## 不採用案 (本 ADR 取り下げ時に検討した分岐)

| 案 | 不採用理由 |
|---|---|
| TCC マイク権限の宣言だけは維持 (試行 1 だけ残す) | 「ファイル名ダイアログでは動く」副次効果は得られるが、本来の目的が未達のまま部分実装を残すと後続混乱の元。再開時に同時復元する方が綺麗 |
| 試行 2/3/4 を main にマージ | 効果が確認できないコードを残すと将来のデバッグを複雑化させる |
| 新規 ADR (0027 等) を作成 | 本件は当初の「マイク権限取得」決定と一連の試行であり、1 ADR にまとめた方が再開時の参照が容易。ADR 0026 を当初 (採用) → 試行 (保留) に巻き戻す形にした |

## 参考リソース

- [cmux PR #1410: Fix macOS dictation NSTextInputClient conformance](https://github.com/manaflow-ai/cmux/pull/1410) — Ghostty が同種の問題を解決した実装の参考
- [cmux PR #857: Fix voice dictation text insertion path](https://github.com/manaflow-ai/cmux/pull/857)
- [kitty issue #9661: macOS double Fn dictation does not start](https://github.com/kovidgoyal/kitty/issues/9661)
- [WWDC23: What's new with text and text interactions](https://developer.apple.com/videos/play/wwdc2023/10058/)
- [Apple Docs: NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient)
- ADR [0001: Electron ではなく Swift/SwiftUI を採用](./0001-swift-swiftui.md) — App Sandbox 無効ポリシーの源流
- ADR [0008: ターミナルでは claude を自動起動しない](./0008-no-claude-autostart.md) — 子プロセス管理の前提
