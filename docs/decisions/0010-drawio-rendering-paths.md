---
title: "0010: drawio ファイルの描画は形式ごとに異なる経路を使う"
description: .drawio.svg の view は inline SVG + WKWebView、.drawio の view は drawio embed (chrome=0)、編集はいずれも drawio embed (chrome=1) を使う形式別経路
status: 採用
derived_from:
  - docs/decisions/0001-swift-swiftui.md
  - docs/decisions/0006-only-swiftterm-dependency.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-09
---

# 0010: drawio ファイルの描画は形式ごとに異なる経路を使う

**日付**: 2026-04-09

## 背景
Aidea の Preview Tool で drawio ファイルを表示する際、対象となる形式は 2 種類ある:

| 形式 | 中身 |
|---|---|
| `.drawio.svg` | 通常の SVG ファイル + `content` 属性に drawio XML を埋め込んだハイブリッド (Obsidian の drawio プラグイン形式) |
| `.drawio` | drawio (mxGraph) の純粋な XML データ。レンダリング済みのグラフィックは含まれない |

両者をどう描画するかで設計判断が必要だった。

## 検討した代替案

### 案A: 全部 drawio embed (`embed.diagrams.net`) で統一
- `.drawio` も `.drawio.svg` も同じ WKWebView + iframe で drawio embed をロード
- `chrome=0` でビューア相当に、`chrome=1` でフルエディタに
- すべての描画を drawio に委譲する一本化アプローチ

### 案B: 形式ごとに最適経路を取る (採用)
- **`.drawio.svg` view**: SVG ファイルの内容を文字列として読み込み、HTML の body に inline SVG として埋め込んで `WKWebView.loadHTMLString` で描画。WebKit のネイティブ SVG レンダラに完全委譲
- **`.drawio.svg` edit**: 案A と同じく drawio embed (chrome=1) を iframe で読み込み、postMessage で XML をロードして編集、保存時は `xmlsvg` 形式でエクスポートして書き戻し
- **`.drawio` view**: drawio embed (chrome=0) を iframe で読み込み、postMessage で XML をロード (純 XML をレンダリングする手段が drawio しかないため)
- **`.drawio` edit**: 同じく drawio embed (chrome=1)、保存時は `xml` 形式で直接 XML を書き戻し

## 判断
**案B (形式ごとに最適経路)** を採用。

## 理由

### `.drawio.svg` view を inline SVG にする決定的な利点

1. **速い**: HTML 文字列を loadHTMLString するだけ。WebKit 起動 → ネット越し drawio ロード → init 待ち → postMessage の往復 → drawio が SVG 再生成、というオーバーヘッドが全部消える (体感ほぼ瞬時 vs 1〜3 秒)
2. **オフライン動作**: ネット接続が無くても `.drawio.svg` は完全に表示できる。SVG は自己完結のラスタ可能フォーマット
3. **メモリ・リソースが軽い**: SVG 1 枚分のみ。案A だと drawio エディタ本体 (数 MB の JS) を毎回ロードする
4. **ロード中のチラつきが無い**: 開いた瞬間に図が出る (案A は spinner が一瞬出る)
5. **そもそも `.drawio.svg` の SVG 部分は drawio が編集時にエクスポート済みの最終成果物**: WebKit に inline で渡すだけで完璧な描画になる。drawio で再生成するのは二度手間

### `.drawio` view を drawio embed にする理由

- 純 XML には描画データが含まれないため、**drawio (mxGraph) のレンダラ以外で表示する手段がない**
- Aidea でレンダラを自前実装するのは現実的でない
- drawio embed の `chrome=0` モードは編集 UI を完全に隠せるため viewer として実用的

### 統一しないデメリット (許容範囲)

- コードパスが 2 本ある (DrawioStaticView 内で 1 つの if 分岐)
- レンダリング経路が違う → 理論的には描画差が出る可能性
  → 実際には drawio が標準 SVG を吐き、WebKit が標準 SVG をパースするので一致する

## 採用したマトリクス

| ファイル | モード | 経路 |
|---|---|---|
| `.drawio.svg` | view | inline SVG → WKWebView |
| `.drawio.svg` | edit | drawio embed (chrome=1) + postMessage + xmlsvg export |
| `.drawio` | view | drawio embed (chrome=0) + postMessage で load |
| `.drawio` | edit | drawio embed (chrome=1) + postMessage + xml export |

## トレードオフ
- 4 パターンの実装が必要 (が、共通化されたラッパ HTML + Coordinator パターンで重複は最小化)
- ファイル形式判定 (`isSVGFormat` 等) の分岐が増える
- 一方で **本質的に異なる物 (画像 vs データ) を別経路にする**のは設計として自然

## 関連
- [Tool 仕様: Preview](../specs/tools/preview.md)
- 関連 ADR: [0001 (Swift+SwiftUI 採用)](./0001-swift-swiftui.md), [0006 (外部依存最小化)](./0006-only-swiftterm-dependency.md)
