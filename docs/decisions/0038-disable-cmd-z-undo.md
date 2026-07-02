---
title: "0038: Cmd+Z (undo / redo) をアプリ全域で無効化する"
description: Cmd+Z 押下でアプリがクラッシュする問題 (issue #228) に対し、undo 経路を安全に保つのではなく Cmd+Z / Cmd+Shift+Z キーと Edit メニューの取り消す/やり直すをアプリ全域で無効化して「何も起こらない」ことを保証する決定
status: 提案
derived_from:
  - docs/decisions/0011-cmd-w-via-nsevent-monitor.md
  - docs/decisions/0014-no-ctrl-number-shortcuts.md
syncs_with:
  - docs/specs/tools/filer.md
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-02
---

# 0038: Cmd+Z (undo / redo) をアプリ全域で無効化する

**日付**: 2026-07-02 / **issue**: #228

## 背景

Cmd+Z を押すとアプリがクラッシュすることがある (issue #228)。

Aidea には undo に到達する経路が複数あり、いずれも安全性を保証しにくい:

1. **SwiftUI Edit メニューの Undo/Redo**: NSEvent モニターで消費しなかった Cmd+Z は
   SwiftUI の `@Environment(\.undoManager)` 経路に落ちる。IME (日本語入力) を伴う
   SwiftUI TextField の undo はクラッシュ事例が知られており、Aidea はタブリネーム・
   クイックメモ等で日本語入力を多用する。
2. **Filer の undoLastOperation**: `FilerSessionState.undoManager` に
   `registerUndo(withTarget: self)` でビュー側オブジェクトをターゲット登録している。
   `NSUndoManager` はターゲットを**非保持 (unowned) 参照**で持つため、ビュー再生成後に
   undo が発火すると解放済みオブジェクト呼び出しで落ちる余地がある。
3. ファイル操作の undo はそもそも**外部状態 (ファイルシステム) に依存**し、
   外部変更後の復元は失敗・不整合を起こしやすい。

クラッシュレポートが残っておらず経路の特定はできないが、いずれの経路も「undo を安全に
動かし続ける」ためのコストが高い。

## 判断

**Cmd+Z / Cmd+Shift+Z をアプリ全域で無効化し、「押しても何も起こらない」ことを保証する。**

| 経路 | 対応 |
|---|---|
| キー入力 (Cmd+Z / Cmd+Shift+Z) | 既存の NSEvent local monitor ([ADR 0011](./0011-cmd-w-via-nsevent-monitor.md)) で消費し、何もしない |
| Edit メニュー (取り消す / やり直す) | `CommandGroup(replacing: .undoRedo) {}` で項目ごと撤去 (マウス経由の発火も塞ぐ) |
| Filer の undoLastOperation (Cmd+Z / Cmd+Shift+Z) | トリガを撤去し無効化。undo 登録コード (`registerUndo` 等) は残置するが発火経路がないため dead になる |

**Ctrl+Z (Emacs 系ページ移動、[filer.md の pageMoveSelection](../specs/tools/filer.md)) は対象外** (modifier が異なり衝突しない)。

## 理由

1. **確実性**: 経路を塞げばクラッシュは構造的に起こらない。undo の安全化 (ターゲットの
   生存管理・IME 問題の回避・ファイルシステム整合) はどれも保守コストが高く、
   個人ツールとして見合わない。
2. **実害が小さい**: Filer の undo はゴミ箱からの手動復元で代替できる。テキスト編集
   (Markdown edit 等) は保存前のファイルが SSoT であり、undo が効かなくても致命的ではない。
3. **前例に整合**: 「特定ショートカットを意図的に使わない」判断は
   [ADR 0014](./0014-no-ctrl-number-shortcuts.md) と同型。

## やらないこと (スコープ外)

- Filer undo 実装 (`registerUndo` / `beginUndoGrouping` 等) の撤去。トリガが無く dead code に
  なるが、将来 undo を安全に再導入する場合の資産として残す (再導入時は本 ADR を置換すること)。
- クラッシュ原因の根本特定 (経路を塞ぐことで目的を達するため)。

## トレードオフ

- **テキスト編集中の undo も効かなくなる** (タブリネーム・クイックメモ・Markdown edit 等)。
  タイプミスは手で直す。issue #228 の「何も起こらないようにする」という要求どおりの挙動。
- Filer のファイル操作 undo (仕様: [filer.md#undolastoperation](../specs/tools/filer.md)) が
  使えなくなる。削除はゴミ箱経由のため Finder から手動復元可能。
