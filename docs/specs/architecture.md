---
title: Architecture
description: Aidea の技術スタック (Swift/SwiftUI/WKWebView/SwiftTerm)・コード配置・レイヤー依存方向・UI レイアウトのアーキ上の注意
derived_from:
  - docs/foundation/vision.md
  - docs/decisions/0001-swift-swiftui.md
  - docs/decisions/0006-only-swiftterm-dependency.md
syncs_with: []
impacts:
  - docs/specs/sessions/terminal.md
  - docs/specs/sessions/web.md
  - docs/specs/aspects/persistence.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-22
---

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

## 機能群の関係

`specs/` のサブディレクトリは機能群を表す。関係性は以下のとおり。

```
┌─────────────────────────────────────────────────────┐
│  window/      アプリ全体 (1 ウィンドウ)             │
│  └─ ダイアログ / グローバルショートカット           │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │  sessions/   状態を持つ実体 (複数)          │    │
│  │  └─ 概念モデル (Window/Pane/Tab/Session/Tool)│    │
│  │  └─ アクティブ切替・履歴                    │    │
│  │  └─ Session 単位の UI ルール                │    │
│  │                                             │    │
│  │  ┌───────────────────────────────────────┐  │    │
│  │  │  tools/    Session の機能種別          │  │    │
│  │  │  filer / kit / terminal / web /        │  │    │
│  │  │  preview / git / gitDiff / claude 等   │  │    │
│  │  └───────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  frontchannels/  Aidea → Claude の通信              │
│    (PTY への送信・recommend モード・scene など)     │
│                                                     │
│  backchannels/   Claude → Aidea の通信              │
│    (ファイル経由・VOICEVOX 読み上げなど)            │
│                                                     │
│  ※ 主に claude tool が双方向で使用                 │
└─────────────────────────────────────────────────────┘
```

**軸の整理**:

- **構造軸** (含有関係): `window/` ⊃ `sessions/` ⊃ `tools/`
  - Window が Session を束ね、Session は Tool 種別を持つ
- **通信軸** (横断的関心): `frontchannels/` / `backchannels/`
  - Aidea と Claude の間の双方向通信チャネル
  - 主に claude tool が利用するが、構造軸とは独立した横断軸

各機能群の個別仕様は [README.md](./README.md) の一覧、
Session 概念の詳細は [sessions/ui-rules.md#概念モデル](./sessions/ui-rules.md#概念モデル) を参照。

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

### 主要コンポーネント

| 型 | 種別 | 責務 |
|---|---|---|
| `SplitLayoutView` | `NSViewControllerRepresentable` | `LayoutConfig` のツリーを再帰的に `NSSplitViewController` に展開し、ツリー構造が変わるたびに root controller を差し替える |
| `LayoutContainerViewController` | `NSViewController` | SwiftUI 側から子 `NSViewController` を丸ごと差し替えられるコンテナ (`childController` の set で旧 controller を外して新 view を貼る) |
| `PaneView` | SwiftUI View | 1 つの物理ペインを表し、タブバー + ZStack で Session View を束ねる。分割ボタン・追加メニュー・ドラッグによるタブ移動もここ |
| `TabSlotView` | SwiftUI View | タブ間の挿入位置を表す 8px 幅のドロップターゲット。`SessionID` をドロップすると `SessionRegistry.moveSession`、`fileURL` (ファイルのみ) をドロップすると `SessionRegistry.openPreviewAtSlot` を呼ぶ |

- レイアウトツリー (`LayoutNode`) の構造変化は `SplitLayoutView.signature(of:)` の文字列比較で検知し、差分があるときだけ再構築する
- 分割ディバイダ位置は `NSSplitView.autosaveName` に `Aidea.split.<node.id>` を設定して AppKit が自動保存する

具体的なウィンドウレイアウト・グローバルショートカットは [window/](./window/README.md) を参照。

---

## データ保存

UserDefaults / Keychain / `<projectRoot>/.aidea/` の 3 つに保存される。詳細は [persistence.md](./aspects/persistence.md) を参照。

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
- [sessions/ui-rules.md#概念モデル](./sessions/ui-rules.md#概念モデル) — UI 5 階層 (Window/Pane/Tab/Session/Tool)
- [../decisions/](../decisions/README.md) — 設計判断記録
