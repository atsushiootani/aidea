# Architecture

Aidea の技術スタックとコード構造。動機と原則は [../foundation/vision.md](../foundation/vision.md) を参照。

---

## プラットフォーム

- **macOS 15 (Sequoia) 以上**
- **Swift 5.9+**
- **Xcode 16+**
- `if #available` による 15 未満への分岐は書かない ([../conventions/rules.md](../conventions/rules.md#never-決して書かないコードパターン))

## フレームワーク

- **SwiftUI** — UI の主体
- **AppKit** — `NSViewRepresentable` / `NSViewControllerRepresentable` 経由で `WKWebView` / `SwiftTerm` / `NSOutlineView` / `NSTextView` をラップ
- **WebKit** — `WKWebView`、`isInspectable = true`
- **CoreServices** — `FSEventStream` でファイルシステム監視
- **Observation** — `@Observable` マクロで State 管理
- **Foundation** / **Security** — Apple 標準

## 外部依存

| パッケージ | 用途 | ライセンス |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | PTY + 端末 UI | MIT |

**SwiftTerm 1 個のみ**。他はすべて Apple 標準で代用する ([ADR 0006](../decisions/0006-only-swiftterm-dependency.md))。

## 技術選定の根拠

Swift + SwiftUI + WKWebView を採用。決め手は「WKWebView が本物の Safari エンジンで Geolocation / OAuth が OS の権限システムで自然に動く」点と、macOS only と割り切れる点。詳細と代替案との比較は [ADR 0001](../decisions/0001-swift-swiftui.md) を参照。

---

## コード配置ルール

`Aidea/Aidea/` 配下は責務別のトップレベルディレクトリで構成する。各ディレクトリの役割:

| ディレクトリ | 役割 |
|---|---|
| `App/` | `@main` エントリ、`AideaApp`、メニュー定義 |
| `Tools/` | `Tool` enum / `SessionID` / `SessionState` protocol などの **種別定義** |
| `Sessions/` | 各 Tool の `SessionState` 実装と `SessionRegistry` (実体・状態管理) |
| `Services/` | 副作用層 (ファイル I/O、プロセス起動、監視、ローダ) |
| `Models/` | 純粋データ構造 (`@Observable` でない) |
| `Views/` | SwiftUI / AppKit ラッパ View (`Views/Sessions/` に各 Session ビュー、`Views/Layout/` にペインコンテナ、`Views/Common/` に共通パーツ) |
| `Utilities/` | 純粋関数・ヘルパー |
| `Resources/` | アセット / Backchannel リソースなど |

サブディレクトリは Tool 名などの責務で切る (例: `Sessions/Filer/` `Services/Filer/` `Views/Sessions/Filer/`)。

コード記述上の規約 (1 ファイル 1 型、プロパティラッパ並び順など) は [../conventions/](../conventions/README.md) を参照。

### レイヤー依存方向

```
Views → Sessions → Services → Models
              ↓
           Tools (enum 定義)
```

- View は Session を参照する
- Session は Service と State を参照する
- Service は Models を参照する
- Tools (`Tool` enum, `SessionID`) は全体から参照される

---

## UI レイアウトのアーキ上の注意

- Pane 容器 (`PaneView`) は **タブバー + ZStack (全 Tab を常時レンダリング)** 構成
- 非アクティブ Tab は `opacity(0)` + `allowsHitTesting(false)` で隠す
  → NSView が superview から外れないので **Terminal の PTY バッファ / WKWebView の状態が失われない**

具体的なウィンドウレイアウト・グローバルショートカットは [window/](./window/README.md) を参照。

---

## データ保存

| データ | 場所 | 用途 |
|---|---|---|
| projectRoot | `UserDefaults` (`aidea.projectRoot`) | 起動時復元 |
| (将来) API キー | macOS Keychain | Claude API セキュア保管 |
| (将来) アプリ設定 | `~/Library/Application Support/Aidea/config.json` | 編集しやすさ |
| (将来) ワークスペース状態 | `~/Library/Application Support/Aidea/workspace.json` | レイアウト + SessionState 復元。保存対象: プロジェクトルート / 各ペインの Session 状態 (表示ファイル / WebView URL / ターミナル cwd 等) / ウィンドウサイズ / スプリット比率 |

---

## 配布

**個人用のみ**。配布ポリシーの前提は [../foundation/vision.md#誰のためか](../foundation/vision.md) を参照。

- Xcode の Personal Team で署名 (無料、Apple ID 登録のみ)
- ビルド後 `~/Applications/Aidea.app` に配置
- Apple Developer Program ($99/年) 不要
- 公証不要、`xattr -cr` で quarantine を剥がせば OK
- **App Sandbox は無効** (`~/.claude/` 読み取り、PTY 起動のため)

---

## 関連ドキュメント

- [../foundation/vision.md](../foundation/vision.md) — 動機・原則
- [../conventions/](../conventions/README.md) — コーディング規約
- [glossary.md](./glossary.md) — 用語集
- [sessions/concept-model.md](./sessions/concept-model.md) — UI 5 階層 (Window/Pane/Tab/Session/Tool)
- [../decisions/](../decisions/README.md) — 設計判断記録
