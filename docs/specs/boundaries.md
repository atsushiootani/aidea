# Boundaries

Aidea の境界。**常に行うこと** / **最初に確認すること** / **決して行わないこと** を明示する。
CLAUDE.md やコードレビュー時に参照する。

## Always (常に行うこと)

- 新しいファイルは `Views` / `Services` / `Models` / `Utilities` / `Sessions` / `Tools` の責務分類に従って配置する
- **1 ファイル = 1 型** (struct/class/enum) の原則を守る
- View プロパティラッパは [coding-style.md](./coding-style.md) の固定順で並べる
- 新しい設計判断は `docs/decisions/` に ADR として追記する
- SessionState はペイン移動で失われないよう、状態オブジェクトとして切り出す

## Confirm First (最初に確認すること)

- **外部依存パッケージを追加する前に必要性を再検討する**
  (SwiftTerm 以外は当面追加しない方針 — ADR 0006)
- 非要件 ([SPEC.md 3 章](./SPEC.md#3-スコープ-scope)) に該当する機能を作りそうになったら立ち止まる
- macOS 15 (Sequoia) 未満の分岐が必要になったら、本当に必要か再考する

## Never (決して行わないこと)

- ❌ **コードエディタ機能を追加しない** (ADR 0002)
- ❌ **macOS 以外への対応コードを書かない** (macOS 専用と割り切る)
- ❌ **macOS 15 (Sequoia) 未満の互換コードは書かない** (`if #available` 分岐なし)
- ❌ **他人配布を前提とした設定** (公証、Developer ID 署名) を組み込まない
- ❌ **設定 UI を作り込まない** (JSON / plist 直接編集で済ませる)
- ❌ **Vibeyard と同じ罠** (`<webview>` / iframe で本物のブラウザ挙動を犠牲にする) を踏まない
- ❌ **ターミナルから claude を自動起動しない** (非対話シェルから起動するとサードパーティ判定されるため — ADR 0008)
- ❌ **グローバル state に "selectedFile" のような cross-tool 状態を置かない**
  (ペイン/Session ごとに独立した状態を持たせ、tool 間連携は明示的な API で行う)

## 参考
- [SPEC.md](./SPEC.md) — 仕様本体
- [decisions/](../decisions/README.md) — 設計判断の記録
