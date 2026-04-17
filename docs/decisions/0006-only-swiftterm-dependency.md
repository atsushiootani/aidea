---
title: "0006: 外部依存は SwiftTerm のみに絞る"
description: Swift パッケージ依存は SwiftTerm 1 個のみとし、他は Apple 標準フレームワークで賄う方針
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-08
---

# 0006: 外部依存は SwiftTerm のみに絞る

**日付**: 2026-04-08

## 判断
外部依存は SwiftTerm 1 つのみ。それ以外は Apple 標準フレームワーク（Foundation, SwiftUI, AppKit, WebKit, Security）で賄う。

## 理由
- 個人プロジェクトで依存が増えると破綻しやすい
- Apple 標準は長期メンテされる保証がある
- サードパーティ依存はアップデートが止まると詰む

## 採用ライブラリ
- **SwiftTerm** (MIT): ターミナル UI。自作は現実的でない

## 採用を見送ったもの
- SwiftGit2 → `git` コマンド直叩きで十分
- Alamofire → `URLSession` で十分
- MarkdownUI → SwiftUI 標準の `Text` + `AttributedString` で様子見
