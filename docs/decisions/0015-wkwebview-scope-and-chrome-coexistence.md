# 0015: WKWebView の制約を許容し Chrome 併用を前提とする

**日付**: 2026-04-15
**状態**: 採用

## 背景

[ADR 0001](./0001-swift-swiftui.md) で Swift + SwiftUI + WKWebView を採用したが、
WKWebView は Safari と同一エンジン (WebKit) であり Chrome とは対応状況が異なる。
Aidea に「万能ブラウザ」を期待すると Web Bluetooth / Web USB / Chrome 拡張機能などで
ハマる可能性があるため、どこまでを WKWebView で賄い、どこから先は Chrome を併用するかを
決定事項として明文化する。

## 判断

- Aidea 内蔵ブラウザは **WKWebView (Safari 相当)** に限定する
- Chrome 固有機能や拡張機能に依存する用途は **外部 Chrome を併用** する
- Aidea が Chrome を置き換えることは目指さない

## 理由

1. WKWebView は Safari と同じ WebKit エンジンなので、Geolocation / OAuth / WebRTC など
   OS 権限が絡む機能が OS 標準ダイアログで自然に動く
2. React / Next.js / Vue 等の一般的な SaaS はほぼ全て Safari で動くため、
   Aidea の想定用途（ローカル開発プレビュー、ドキュメント閲覧、AI 連携）では実用上問題ない
3. Chrome 固有機能 (Web Bluetooth / USB / Serial / `showOpenFilePicker` / 拡張機能) は
   macOS の既存 Chrome に任せる方が、無理に代替実装するより保守コストが低い

## WKWebView ≈ Safari で動くもの

| 機能 | 備考 |
|---|---|
| HTML / CSS / JS レンダリング | Safari と同一エンジン |
| Geolocation | macOS CoreLocation 経由、権限ダイアログは OS 標準 |
| WebRTC (カメラ・マイク・画面共有) | OS の権限システム |
| Service Worker | ✓ |
| IndexedDB / localStorage | ✓ |
| Fetch / WebSocket | ✓ |
| Notifications | macOS 通知センター連携 |
| OAuth popup | `WKUIDelegate` で handle すれば完璧 |
| Cookie 永続化 | `WKHTTPCookieStore` |
| Web Inspector | `webView.isInspectable = true` + Safari 開発メニュー |

## Safari 本体との差異 (許容する)

| 差異 | 影響 |
|---|---|
| Cookie / Session が独立 | Safari 本体のログイン状態は共有されない。Aidea 内で一度ログインすれば永続化はされる |
| iCloud Keychain 非対応 | Safari に保存したパスワードは自動入力されない |
| Safari 拡張機能非対応 | uBlock / 1Password 等は使えない |
| Reader Mode / Translate 非対応 | Safari 独自 UI 機能は無し |

## Chrome と比較したときの制約 (Chrome 併用で解決)

| 機能 | Chrome | WKWebView |
|---|---|---|
| Web Bluetooth | ✓ | ✗ |
| Web USB | ✓ | ✗ |
| Web Serial | ✓ | ✗ |
| File System Access API (`showOpenFilePicker`) | ✓ | ✗ |
| WebGPU | ✓ 安定 | ⚠ macOS 14+ で実験的 |
| WebM (VP9) コーデック | ✓ | ⚠ macOS 11+ のみ |
| PWA インストール | ✓ | ⚠ 限定的 |
| Chrome DevTools | ✓ 最強 | Safari Web Inspector を代用 |
| Chrome 拡張機能 | ✓ | ✗ |

## 運用方針

| 用途 | 使うツール |
|---|---|
| ローカル開発プレビュー | **Aidea の WKWebView** |
| Safari 互換性チェック | Aidea の WKWebView (Safari と同等) |
| Chrome 固有機能の確認 | 別途 Chrome |
| 拡張機能 (1Password 等) | 別途 Chrome |
| Playwright MCP 接続先 | 別途 Chrome (`--remote-debugging-port` 起動) |

## トレードオフ

- Chrome 固有 API が必要なユーザーは二つのブラウザを行き来する手間が残る
- Aidea 側で扱えない Web API が増えた場合、その都度「Chrome 併用」ですませるか個別対応するか判断が必要
