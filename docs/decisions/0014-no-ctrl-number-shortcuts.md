# 0014: Ctrl+数字キーのショートカットを使わない

**日付**: 2026-04-14
**状態**: 採用

## 背景
Git ツールのモード切替（Working Changes / PR Preview）に Ctrl+1 / Ctrl+2 を
割り当てようとしたが、キー入力がアプリに届かなかった。

以下の方法をすべて試したが、いずれも反応しなかった：
- NSOutlineView サブクラスの `keyDown` で `event.modifierFlags.contains(.control)` を判定
- NSEvent.addLocalMonitorForEvents で捕捉
- SwiftUI の CommandMenu + `.keyboardShortcut("1", modifiers: [.control])`

## 原因
macOS の **Mission Control** がシステムレベルで Ctrl+数字キーを横取りしている。

システム環境設定 → キーボード → ショートカット → Mission Control：
- Ctrl+1 = デスクトップ1に切り替え
- Ctrl+2 = デスクトップ2に切り替え
- Ctrl+3 = デスクトップ3に切り替え
- ...

このショートカットはアプリにイベントが届く前にシステムが消費するため、
NSEvent ローカルモニターでも SwiftUI の keyboardShortcut でも捕捉できない。

Ctrl+4 / Ctrl+5 はデスクトップを4つ以上作っていなければ動作するが、
ユーザーがデスクトップを増やすと同じ問題が再発する。

## 判断
**Ctrl+数字キーのショートカットは使わない。**
代わりに修飾キーなしの単一キー（W / P 等）を使う。

Git ツールのモード切替は以下のキーバインドとした：
- **W** = Working Changes
- **P** = PR Preview
- **Ctrl+4 / Ctrl+5** = 補助的に対応（動作する環境向け）

## 理由
1. Ctrl+数字は macOS システムに横取りされ、アプリで確実に受け取れない
2. 単一キーは NSOutlineView の `keyDown` で確実に受け取れる
3. Git ツールがフォーカスされている時のみ有効なので、他の入力と競合しない
4. W (Working) / P (PR) は頭文字で覚えやすい

## 一般的な注意
macOS アプリでキーボードショートカットを設計する際、以下の修飾キー+キーの組み合わせは
システムに横取りされる可能性がある：
- **Ctrl+数字**: Mission Control のデスクトップ切替
- **Ctrl+上下**: Mission Control / App Exposé
- **Ctrl+左右**: デスクトップ間スワイプ
