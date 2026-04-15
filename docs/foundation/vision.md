# Vision

Aidea を作る動機・ターゲット・原則・成功基準を置く。
**ストック情報** (コードに直接紐づく設計) は [../specs/](../specs/README.md) を参照。
**フロー情報** (MVP 範囲・実装スケジュール・未実装アイデア) は GitHub **Issues** (`enhancement` ラベル) で管理。

---

## 何を作るか

macOS ネイティブの個人用 AI コーディングワークスペース。
コードエディタは含まず、ターミナル・WebView・AI エージェント連携・ローカルファイル参照を 1 つのアプリに統合する。

## 誰のためか

- **ターゲット: 開発者本人 1 名のみ**
- 他人への配布、App Store 公開、複数ユーザー対応はしない

---

## 作る理由

### 試した道: Vibeyard

Electron 製の AI コーディング IDE (Vibeyard) を試したが、以下の問題が判明:

- `<webview>` タグの制約で **位置情報 (Geolocation) が取れない**
- `<webview>` の popup ハンドリング欠如で **OAuth ログインが壊れる**
- `permission request handler` が未設定で多くの Web API が拒否される
- User-Agent が Electron 由来でサイトによっては bot 扱い
- Chrome プロファイル (Cookie、拡張機能) が使えない

Vibeyard の Inspect / Flow Recording 機能自体は面白いが、
**IDE 固有のバグと永続的に付き合うデメリットが、統合 UX のメリットを上回る** と判断。

### 判断

- Vibeyard は使わない
- 当面の実用環境は **Chrome + Playwright MCP + Claude Code** の組み合わせで済ませる
- **「作る楽しみ」と「長期的な自分仕様」の両立** のため、週末プロジェクトとして自作 IDE を育てる

---

## 原則

> **本来のブラウザの挙動と差異なく開発できることが最優先**
>
> 統合された UX は便利だが、それは手段。本物のブラウザで動くものが動かなかったり、
> 挙動が違ったりすることに耐えてまで統合は求めない。

この原則が技術選定 ([ADR 0001](../decisions/0001-swift-swiftui.md)) と
スコープ判断 ([ADR 0015](../decisions/0015-wkwebview-scope-and-chrome-coexistence.md)) の根拠。

---

## 成功基準

- **1 年後 (2027-04 目安)、JetBrains を開く時間より Aidea を開く時間の方が長くなっている**
- 具体的には、その時点で以下ができていること:
  - ターミナルで Claude Code を起動して普通に開発できる
  - `~/.claude/skills` などの Claude リソースを GUI で一覧できる
  - WKWebView で localhost プレビューが Safari と同等に動く
