# WKWebView vs Safari vs Chrome

Aidea は WKWebView を使う。これは **Safari とほぼ同等だが完全一致ではない**。Chrome とは Web 標準対応の範囲で差異がある。ここではその差異を正直に記録する。

## WKWebView ≈ Safari

WKWebView は Safari と同じ **WebKit (JavaScriptCore + WebCore)** を使っている。Electron の `<webview>` のような制限はない。

### 同じように動くもの

| 機能 | 備考 |
|---|---|
| HTML / CSS / JS レンダリング | Safari と同一エンジン |
| Geolocation | **macOS CoreLocation 経由、権限ダイアログは OS 標準** |
| WebRTC（カメラ・マイク・画面共有） | OS の権限システム |
| Service Worker | ✓ |
| IndexedDB / localStorage | ✓ |
| Fetch / WebSocket | ✓ |
| Notifications | macOS 通知センター連携 |
| OAuth popup | `WKUIDelegate` で handle すれば完璧 |
| Cookie 永続化 | `WKHTTPCookieStore` |
| Web Inspector | `webView.isInspectable = true` + Safari 開発メニュー |

### Safari と違うもの

| 違い | 影響 |
|---|---|
| Cookie / Session が独立 | Safari 本体のログイン状態は共有されない。Aidea 内で一度ログインすれば永続化はされる |
| iCloud Keychain 非対応 | Safari に保存したパスワードは自動入力されない |
| Safari 拡張機能非対応 | uBlock、1Password 等のブラウザ拡張は使えない |
| Reader Mode / Translate 非対応 | Safari 独自 UI 機能は無し |

## WKWebView vs Chrome

これは実質 **Safari vs Chrome の差異** そのもの。

### Chrome で動くが WKWebView では動かない / 制限あり

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

### 実用上の差

多くの一般的な Web アプリ（React、Next.js、Vue、Web フレームワーク製 SaaS）は **Safari で動くので WKWebView でも動く**。

Aidea の想定用途（ローカル開発サーバーのプレビュー、ドキュメント閲覧、AI との連携）では、**ほぼ 100% 問題ない**。

### 問題になるケース

- Web Bluetooth / USB / Serial を使う開発（IoT 等）
- Chrome 固有機能に依存する PWA
- `showOpenFilePicker` 前提のファイル操作 UI
- Chrome 拡張機能に依存したワークフロー

これらが必要な場合は **別途 Chrome を起動して併用** する。Aidea はそれを置き換えるものではない。

## 運用方針

| 用途 | 使うツール |
|---|---|
| ローカル開発プレビュー | **Aidea の WKWebView** |
| Safari 互換性チェック | Aidea の WKWebView (Safari と同等) |
| Chrome 固有機能の確認 | 別途 Chrome |
| 拡張機能（1Password等） | 別途 Chrome |
| Playwright MCP 接続先 | 別途 Chrome (`--remote-debugging-port` 起動) |

**両方あることが前提**。Aidea は Chrome を置き換えない。Safari ベースの本物ブラウザを IDE 内に持つことで、Vibeyard の `<webview>` 地獄を回避するのが目的。

## Vibeyard `<webview>` との違い

参考までに、Electron の `<webview>` タグと WKWebView の本質的な違い：

| 項目 | Electron `<webview>` | WKWebView |
|---|---|---|
| エンジン | Chromium (Blink) | WebKit (Safari) |
| 権限 | デフォルト拒否、アプリ側で `setPermissionRequestHandler` 設定必須 | OS 標準の権限ダイアログ |
| Popup | `new-window` イベント手動 handle 必須 | `WKUIDelegate` で handle |
| プロセス分離 | あり（別 renderer） | あり（別 process） |
| preload スクリプト注入 | 可能 | 可能（`WKUserScript`） |
| Geolocation | Google API key 必須（Electron にバンドルされてない） | OS CoreLocation 直結 |
| OS との統合 | 浅い | 深い |
| Electron 公式の扱い | **非推奨** (`WebContentsView` 推奨) | — |

WKWebView は **Apple のフレームワークなので OS と深く統合されている**。Electron の `<webview>` のような「アプリ側で全部 hook しないと何も動かない」状況にはならない。
