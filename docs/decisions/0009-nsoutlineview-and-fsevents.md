---
title: "0009: ファイラは NSOutlineView + FSEvents で実装する"
description: Finder 基盤の NSOutlineView と CoreServices の FSEventStream でファイラのツリー UI とファイル変更検知を実装する判断
status: 採用
derived_from:
  - docs/decisions/0006-only-swiftterm-dependency.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-08
---

# 0009: ファイラは NSOutlineView + FSEvents で実装する

**日付**: 2026-04-08

## 背景
左上ペインに置くファイラ機能を実装するにあたり、ツリー UI とファイル変更検知の
2 つの技術選定が必要になった。

## 検討した代替案

### ツリー UI
- **(A) SwiftUI `List` + `OutlineGroup`**: 宣言的で 30 行で書けるが、大きなツリーで
  全ノードを事前展開しがち。1000 件超で体感が落ちる。遅延読み込みは自前で書く必要あり
- **(B) NSOutlineView (AppKit)**: NSViewControllerRepresentable でラップ。実装ボリュームは
  200〜400 行と多めだが、Finder 自体の基盤で数万件でも高速。遅延読み込み・列・SF Symbols 表示が
  ネイティブにサポートされる
- **(C) サードパーティ製 SwiftUI ツリーライブラリ**: 外部依存方針 (ADR 0006) に反する

### ファイル変更検知
- **(α) `DispatchSource.makeFileSystemObjectSource`**: 単一ファイルしか監視できず、
  ディレクトリ配下の再帰監視には向かない
- **(β) `FSEventStream` (CoreServices)**: ディレクトリ配下を再帰的に監視できる macOS 標準 API。
  C API なので Swift ラッパが必要だが、軽量で枯れている
- **(γ) ポーリング**: 単純だが CPU を食う / 反応が遅い

## 判断
- ツリー UI: **(B) NSOutlineView**
- ファイル変更検知: **(β) FSEventStream**

## 理由

### NSOutlineView を選んだ理由
1. **将来の拡張余地**: 編集系操作 (リネーム/D&D) や複数選択は NSOutlineView ならネイティブ
2. **大規模プロジェクト対応**: 数千ファイル超でも遅延読み込みで体感が落ちない
3. **既存 SwiftTerm/WebView と同じ NSViewRepresentable パターン**で統一感がある
4. ADR 0006 の「外部依存最小化」とも整合する (Apple 標準)

### FSEventStream を選んだ理由
1. ディレクトリ配下を 1 ストリームで再帰監視できる
2. レイテンシ数 ms、バッテリー負荷小
3. macOS 標準で長期サポート保証
4. Aidea は macOS 専用なのでクロスプラットフォーム互換性を考えなくてよい

## 実装上の注意点
- **`kFSEventStreamCreateFlagUseCFTypes` を付けると `eventPaths` は CFArray になる**。
  C 文字列配列としてアクセスするコードと同時に使うとクラッシュするため、
  Aidea ではこのフラグを付けず C 文字列配列モードで運用している
- **デバウンス必須**: `.git` などのディレクトリは連続的に書き換わるため、
  200ms のデバウンスでまとめてリロードする
- **除外ディレクトリ**: `.git`, `node_modules`, `DerivedData`, `.build` は走査・監視ともに
  スキップする (パフォーマンスとノイズ抑制の両面で)
- **`Unmanaged.passUnretained`**: コールバックに self を渡すときは passUnretained を使い、
  FileWatcher のライフサイクルは保持側 (FileTreeViewController) が責任を持つ

## トレードオフ
- NSOutlineView ラッパは 200 行以上のコード量がある (SwiftUI OutlineGroup なら 30 行)
- AppKit のデータソース/デリゲートパターンは SwiftUI の宣言的スタイルと相性悪い
- FSEventStream は C API なのでデバッグが少し面倒

## 関連 ADR
- [0006](./0006-only-swiftterm-dependency.md) — 外部依存最小化方針との整合
