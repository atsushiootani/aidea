---
title: "0001: Electron ではなく Swift/SwiftUI を採用"
description: Vibeyard の webview 制約を避けるため Swift + SwiftUI + WKWebView を採用する技術選定判断
status: 採用
derived_from:
  - docs/foundation/vision.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-08
---

# 0001: Electron ではなく Swift/SwiftUI を採用

**日付**: 2026-04-08

## 背景
Vibeyard（Electron 製）を試用したが、`<webview>` タグの制約で位置情報・OAuth・permission API 等が壊れる問題を確認。

## 検討した代替案
- Electron + TypeScript + React
- Tauri + Rust + React
- Swift + SwiftUI
- Flutter Desktop
- Zed 方式（Rust + GPU）

## 判断
**Swift + SwiftUI + WKWebView** を採用。

## 理由
1. WKWebView は **Safari と同じ WebKit エンジン**で、Geolocation や OAuth が OS の権限システムで自然に動く
2. macOS 専用と割り切ることで、クロスプラットフォームの妥協が不要
3. `Process` / `URLSession` / `FileManager` で外部連携が自然
4. 長期メンテ時、Apple の公式フレームワークの方が安定

## トレードオフ
- Chrome 固有機能（Web Bluetooth 等）は WKWebView で動かない → 別途 Chrome を併用
- Electron に比べ UI 開発のホットリロードは弱い → Xcode Previews で代替
- Rust / Tauri よりエコシステムは狭い領域あり（ただし macOS only なら Apple 側が手厚い）
