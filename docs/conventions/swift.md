# Swift / SwiftUI 規約

SwiftUI と AppKit (NSView) の使い分けに関する規約。Aidea は **SwiftUI を第一選択** とし、
NSView は「代替不可」が示せる場合に限って、最小範囲に閉じ込めて使う。

一般的な Swift コーディング規約 (プロパティラッパ並び順・コメント方針・並行性等) は
[coding-style.md](./coding-style.md) を参照。

---

## 基本方針

- **新規 View は SwiftUI で書く**
- NSView / AppKit を持ち出すのは、下記「許容理由」のいずれかに該当する場合のみ
- 持ち出した場合も、**できるだけ狭い範囲に閉じ込め、すぐ SwiftUI で囲む**

> SwiftUI が macOS 15 (Sequoia) 以上で十分に使えることが前提。
> `if #available` で古い OS 向けに AppKit フォールバックを書くことは禁止 ([rules.md](./rules.md#never-決して書かないコードパターン))。

---

## NSView / AppKit が許容される理由

新規に NSView を持ち出す場合、Representable のドキュメントコメントに下記いずれかの**具体的な理由**を明記する。
該当しない場合は SwiftUI で書き直すこと。

### A. SwiftUI に同等 API が存在しない

- **First Responder の精密な制御** (キーイベントの個別ハンドリング・`noResponder` 抑制)
- **NSSplitViewController の divider 位置 autosave**
- **`NSOutlineView` 相当のキーボード操作・コンテキストメニュー**
- **`NSEvent.addLocalMonitorForEvents` によるグローバルイベント監視**

### B. SwiftUI 実装のパフォーマンスが実用に耐えない

- **大きなプレーンテキストの編集**: `TextEditor` は数万行で著しく重くなるため `NSTextView` を使用
- 他のケースでは**まず SwiftUI で書いて計測**してから持ち出すこと (思い込みで AppKit に逃げない)

### C. 外部依存がそもそも AppKit ベース

- **SwiftTerm** (`LocalProcessTerminalView`) — ADR 0006 で唯一の外部依存として採用済
- **WKWebView** (drawio / Markdown プレビュー / Web セッション)

上記 A〜C 以外の理由で NSView を使いたくなった場合は、**先に [docs/decisions/](../decisions/README.md) に ADR を追加**してから実装する。

---

## 閉じ込めルール

### 必ず Representable でラップする

- NSView は必ず `NSViewRepresentable` または `NSViewControllerRepresentable` でラップする
- SwiftUI View の中から直接 `NSHostingView` / `NSWindow` に触らない (ウィンドウ管理は Services 層で閉じる)

### SwiftUI ツリーを外側に保つ

- **Representable の親は必ず SwiftUI View** とする
- NSView ヒエラルキを SwiftUI の外まで伸ばさない (AppKit のみで完結する画面は作らない)
- 例外: `NSSplitViewController` 経由の子 `NSHostingController` など、Representable 内部で閉じた NSView ツリーは許容

### Representable の公開 API は SwiftUI 型で閉じる

- 外部に露出するプロパティは **`let` / `@Binding` / クロージャ** のみ
- 内部実装 (`NSTextView` / `WKWebView` / `NSOutlineView` 等) を戻り値・引数に出さない
- First Responder 報告など「SwiftUI に戻せない情報」だけ `onViewCreated: (NSView) -> Void` のようなコールバックで最小限に露出する

### 1 ファイル 1 型の例外 (明示的に許容)

通常 Aidea は [1 ファイル 1 型](./coding-style.md#swift-規約) を原則とするが、下記の組み合わせは同一ファイルへの同居を許容する:

- `NSViewRepresentable` 本体
- その `Coordinator`
- Representable 専用の NSView サブクラス (他から参照されないもの)
- Representable 専用の delegate プロキシ (他から参照されないもの)

理由: これらは Representable の実装詳細であり、分割するとクロスファイル依存が不必要に増える。
**他の Representable や Service から使われる NSView サブクラスは別ファイルに切り出すこと** (例: `FilerOutlineView` / `PersistentTerminalView`)。

---

## `import AppKit` 単体利用

SwiftUI View が AppKit から**値型・ユーティリティだけを使う**ケースは許容する。

### 許容される用途

- `NSEvent` / `NSEvent.modifierFlags` (キーイベント判定)
- `NSPasteboard` (クリップボード操作)
- `NSColor` / `NSFont` (SwiftUI 型に変換して使用)
- `NSWorkspace` (外部 URL を開く等)

### 禁止される用途

- SwiftUI View から NSView を生やすこと (Representable を使わずに `NSView()` をインスタンス化する等)
- AppKit の `NSWindow` / `NSPanel` を直接生成すること (Window 管理は SwiftUI `WindowGroup` / `Window` または Services 層で行う)

---

## SwiftUI View の AppKit ブリッジ制約

一部の SwiftUI View は内部的に AppKit (NSView) にブリッジされており、
SwiftUI のレイアウト修飾子が期待通りに動かないケースがある。

### ブリッジ一覧と制約

| SwiftUI View | AppKit ブリッジ先 | 制約 |
|---|---|---|
| `Menu` | NSPopUpButton / NSMenuItem | `.resizable().frame()` による Image リサイズが効かない。アイコンサイズが NSMenuItem に固定される |
| `contextMenu` | NSMenu | Menu と同じ。アイコンサイズ固定 |
| `Picker` (.menu スタイル) | NSPopUpButton | Menu と同じ |
| `Toggle` (.switch スタイル) | NSSwitch | サイズが固定され、`.frame()` で変更不可 |
| `DatePicker` | NSDatePicker | スタイルのカスタマイズが制限される |
| `ColorPicker` | NSColorWell | サイズが固定される |
| `TextEditor` | NSTextView | 一部のテキストスタイル制御が効かない |
| `ShareLink` | NSSharingServicePicker | レイアウトが制約される |
| `MenuBarExtra` | NSStatusBarButton | サイズ・レイアウトが制約される |

### 推奨する代替案

| 問題 | 代替案 |
|------|--------|
| Menu 内で画像をリサイズしたい | **Popover** に置き換える。Popover は SwiftUI ネイティブなので `.resizable().frame()` が正しく動く |
| Menu 内で複雑なレイアウトを組みたい | **Popover** または **Sheet** に置き換える |
| contextMenu でカスタム View を使いたい | **.overlay + タップ検知** で独自メニューを実装する |
| Toggle のサイズを変えたい | カスタム Toggle スタイルを実装する |

### 判断基準

- ポップアップ系 UI で**テキストのみ**表示する場合 → `Menu` / `contextMenu` で問題なし
- ポップアップ系 UI で**カスタム画像・複雑なレイアウト**が必要な場合 → `Popover` を使う
- 迷ったら **Popover を選ぶ**（SwiftUI の修飾子がすべて正しく動く）

> 実例: `ScenePromptsEditorView` のコンパニオン選択を `Menu` から `Popover` に変更した際、
> `.resizable().frame()` による Image リサイズが正しく動作するようになった。

---

## `@Observable` のアクセスパターン (AttributeGraph cycle 対策)

高頻度に書き換わる状態を `@Observable` プロパティとして公開する場合、View から read する経路に注意する。

### 症状

一つの `@Observable` オブジェクトを View 本体から走査用途 (`ForEach` 等) で読んでいるところに、同じオブジェクトの別プロパティを PTY 出力等で **毎秒数十回〜** flip させると、以下が起きる:

- コンソールに `AttributeGraph: cycle detected` 相当のログが大量に出続ける (例外 / クラッシュには至らない)
- 当該 View が描画更新されなくなる (アイコンが固まる・配置が古いまま)

### 実例 (issue #45)

`CompanionView` は `CompanionStore` を `@Environment` で受け、`ForEach(store.companions)` でアイコンを並べている。表情切替のため `store.busyCompanions: Set<Int>` を追加し、`ClaudeSessionState.noteTerminalOutput` (PTY 出力ハンドラ) から `store.markBusy(index, true/false)` で flip したところ、上記症状が出て Companion アイコンが描画されなくなった。

### 解決パターン

**高頻度 write を別の `@Observable` に切り出す**。View が走査する「コレクション状態」と、PTY 等で高頻度に flip する「フラグ状態」は、必ず別オブジェクトに置く。

| 状態 | 置き場所 | 公開名 |
|---|---|---|
| Companion 配列 (sessionID 紐付け含む) | `CompanionStore` | `companions` |
| 個別セッションの実行中フラグ | `ClaudeSessionState` | `isBusy` |
| VOICEVOX 再生中の companionIndex | `SpeechQueue` | `currentlySpeakingIndex` |

`CompanionView` は `store.companions` から個別 Companion を走査し、各 Companion の `sessionID` から `registry.session(for:).state as? ClaudeSessionState` を引いて `isBusy` / `isSpeaking` を読む。高頻度 write は `ClaudeSessionState` 内で閉じるため、`CompanionStore` の observation graph に影響を与えない。

### アンチパターン

- ❌ 1 つの `@Observable` を `ForEach` 用途と高頻度フラグ用途の**両方**に使う
- ❌ Store が保持する配列要素 (struct) に高頻度 mutate されるフラグを足す
  (配列書き換えとして Observable 通知が走査側にも伝播する)
- ❌ 高頻度 write 問題の回避策として、フラグ書き込みを `DispatchQueue.main.async` で遅延させて誤魔化す
  (描画が止まる症状は消えても、同期が取れず表情が一瞬遅れる等の二次問題が出る。素直にオブジェクトを分ける)

### 迷ったときの判断基準

- View body から同じ `@Observable` の **2 つ以上のプロパティ** を read しそうになったら、そのうち 1 つでも「1 秒に数回以上 write される」ものがあるか確認する
- 該当するなら、その高頻度 write は別 Observable (Session 単位の State など) に切り出す

---

## 参考

- [coding-style.md](./coding-style.md) — Swift 規約全般
- [rules.md](./rules.md) — Always / Confirm First / Never
- [../decisions/0001-swift-swiftui.md](../decisions/0001-swift-swiftui.md) — SwiftUI を第一選択とした技術選定
- [../decisions/0006-only-swiftterm-dependency.md](../decisions/0006-only-swiftterm-dependency.md) — 外部依存は SwiftTerm のみ
- [../specs/architecture.md](../specs/architecture.md) — 全体アーキテクチャ
