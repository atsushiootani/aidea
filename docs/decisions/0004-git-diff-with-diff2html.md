# 0004: Git diff は WebView + diff2html で表示

**日付**: 2026-04-08
**状態**: 暫定

## 背景
`git diff` の出力を見やすく表示する必要がある。

## 検討案
- SwiftUI でネイティブ描画
- NSTextView で属性付き文字列
- WebView に HTML を流し込む

## 判断
**WebView + [diff2html](https://diff2html.xyz/)** を採用（暫定）。

## 理由
1. 既に WKWebView がアプリに含まれている
2. diff2html は枯れた JS ライブラリで見た目が最強
3. シンタックスハイライトも diff2html が担当
4. 自作で描画するより圧倒的に楽

## 見直し条件
- パフォーマンス問題が出たら（大きな diff で重い）
- よりネイティブ感を出したくなったら
