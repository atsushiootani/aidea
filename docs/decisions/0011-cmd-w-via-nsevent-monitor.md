# 0011: Cmd+W による「タブを閉じる」は NSEvent local monitor で実装する

**日付**: 2026-04-09
**状態**: 採用

## 背景
Issue #21 で、どの Tool にフォーカスがあっても共通で効くグローバルショートカットを導入した。
その中に **Cmd+W = 現在のタブを閉じる** がある。しかし macOS + SwiftUI の環境では、
Cmd+W は **SwiftUI の WindowGroup が自動生成する「Close Window」メニュー項目にデフォルトで割り当てられ**ており、
何もしないとウィンドウ (= アプリ) が閉じてしまう。

## 検討した代替案

### 案 A: `CommandMenu("タブ")` に Cmd+W を割り当てる
SwiftUI の `.commands` ブロックで自前のメニュー項目に `.keyboardShortcut("w", modifiers: [.command])` を付けるだけで済むつもりだった。
→ **NG**: SwiftUI のデフォルト Close Window の方が優先され、アプリウィンドウが閉じてしまう。

### 案 B: `AideaAppDelegate` を `NSApplicationDelegateAdaptor` で注入し、
`applicationDidFinishLaunching` で `NSApp.mainMenu` を走査して
`⌘W` / `performClose(_:)` アクションの項目を削除する
→ **NG**: 実装して試したが **メニューから Close 項目が消えず、Cmd+W でアプリが閉じ続けた**。
SwiftUI が applicationDidFinishLaunching より後でメニューを確定しているか、
項目を差し替える API 的な経路が別にある可能性。挙動は環境依存で不安定だった。

### 案 C: `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` で Cmd+W を横取りする (採用)
keyDown イベントをアプリケーション内で受け取った直後、メニュー経路に渡る前に
クロージャが呼ばれる。`Cmd` だけ (他モディファイア無し) で `characters == "w"` のとき
自前のタブクローズを実行し、`return nil` でイベントを破棄する。
→ **OK**: Cmd+W が Close Window メニューに届かず、期待通り「タブを閉じる」に置き換わる。

## 判断
**案 C (`NSEvent.addLocalMonitorForEvents`)** を採用。

実装は `AideaApp.registerKeyEventMonitor()` に集約し、
スタティックヘルパ `closeCurrentTabStatic(layout:registry:)` を呼ぶ。
モニター登録は `ContentView.onAppear` で 1 度だけ行う。

## 理由
1. **確実に動く**: OS の keyDown 取り回しに直接フックするので SwiftUI のメニュー経路に依存しない
2. **副作用が最小**: File メニューから Close 項目を消す副作用が無い (将来メニューから明示的に閉じたい場合も対応しやすい)
3. **条件分岐が書きやすい**: Shift/Option/Control が同時押しの場合はスルーできるので他のショートカットと競合しない

## トレードオフ
- SwiftUI の純度が下がる (AppKit の NSEvent API に依存)
- `self` の State を直接クロージャに渡せないので、スタティックヘルパを用意する必要がある
- **File メニュー上は Close 項目が残ったまま** (ショートカット経由では我々のハンドラが動くが、メニュー項目自体は表示される)
  → 将来メニュー項目の削除方法が安定して確立されたらこの ADR を更新する

## 関連
- [window/shortcuts.md](../specs/window/shortcuts.md) — グローバルショートカット一覧
- GitHub issue #21
