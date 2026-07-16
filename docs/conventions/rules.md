---
title: Rules
description: コードを書くときに常に守る (Always) / 立ち止まる (Confirm First) / 絶対やらない (Never) ルール集
derived_from: []
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-24
---

# Rules

コードを書くときに **常に守る / 立ち止まる / 絶対やらない** ルール。
CLAUDE.md やコードレビュー時のチェックリストとして機能する。

プロダクトとして「やらないこと」の宣言は [../foundation/vision.md#やらないこと](../foundation/vision.md) を参照。

---

## Always (常に行うこと)

- 新しいファイルは `Views` / `Services` / `Models` / `Utilities` / `Sessions` / `Tools` の責務分類に従って配置する
- **1 ファイル = 1 型** (struct/class/enum) の原則を守る
- View プロパティラッパは [coding-style.md](./coding-style.md) の固定順で並べる
- 新しい設計判断は `docs/decisions/` に ADR として追記する
- SessionState はペイン移動で失われないよう、状態オブジェクトとして切り出す
- レイアウトツリーのミューテーション (`splitLeaf` / `removeLeaf` 等) は `DispatchQueue.main.async` で次 runloop に遅延させる (SwiftUI update サイクル内で実行すると `AttributeGraph precondition failure` でクラッシュする)
- 高頻度に write される `@Observable` プロパティ (PTY 出力ごとの busy フラグ等) は、View が `ForEach` 等の走査で read する Observable とは別オブジェクトに置く (詳細は [swift.md](./swift.md#observable-のアクセスパターン-attributegraph-cycle-対策))
- SwiftUI / AppKit のコールバック (`NSViewRepresentable.makeNSView` / `updateNSView` / SwiftTerm 等のデリゲート / Timer.common) から `@Observable` プロパティを同期 write しない。必ず `DispatchQueue.main.async` で次 runloop tick に遅延させる (view update サイクル内で書くと AttributeGraph cycle が発生し、同一ウィンドウの全 View が描画されなくなる)

---

## Confirm First (最初に確認すること)

- **外部依存パッケージを追加する前に必要性を再検討する**
  (SwiftTerm 以外は当面追加しない方針 — ADR 0006)
- [../foundation/vision.md#やらないこと](../foundation/vision.md) または GitHub Issues `wontfix` で「やらない」と決めた領域に該当する機能を作りそうになったら立ち止まる
- macOS 15 (Sequoia) 未満の分岐が必要になったら、本当に必要か再考する

---

## Never (決して書かないコードパターン)

プロダクトレベルの「やらない」宣言は [../foundation/vision.md#やらないこと](../foundation/vision.md) を参照。ここでは **実装上のアンチパターン** のみ扱う。

- ❌ **macOS 15 (Sequoia) 未満の互換コードは書かない** (`if #available` 分岐なし)
- ❌ **Vibeyard と同じ罠** (`<webview>` / iframe で本物のブラウザ挙動を犠牲にする) を踏まない
- ❌ **ターミナルから claude を自動起動しない** (非対話シェルから起動するとサードパーティ判定されるため — ADR 0008)
- ❌ **グローバル state に "selectedFile" のような cross-tool 状態を置かない**
  (ペイン/Session ごとに独立した状態を持たせ、tool 間連携は明示的な API で行う)

---

## 参考

- [coding-style.md](./coding-style.md) — Swift の表面規約
- [design-principles.md](./design-principles.md) — 設計思想 (Tell Don't Ask など)
- [testing.md](./testing.md) — テスト戦略
- [../specs/window/](../specs/window/README.md) — Window 全体の振る舞い (ダイアログ・ショートカット)
- [../specs/sessions/ui-rules.md](../specs/sessions/ui-rules.md) — Session 単位の UI ルール
- [../decisions/](../decisions/README.md) — 設計判断の記録
