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

## UI Conventions (UI 共通ルール)

すべての Tool / Session でこの規約に従う。個別の Tool 仕様
(`docs/specs/tools/*.md`) はこの規約を前提にして記述する。

### ダイアログ
- **Cancel ボタンは Esc キーで発火する**: すべての `NSAlert` / 独自モーダルダイアログで共通。実装上は Cancel に相当するボタンに `keyEquivalent = "\u{1b}"` を明示的に割り当てる
- **OK ボタンは Enter キーで発火する** (NSAlert は first button に自動割当なので追加作業不要)
- **破壊的操作 (削除・上書き等) は必ず確認ダイアログを挟む**
- **ファイル/ディレクトリ名などの入力時はリアルタイムバリデーション** を行い、エラー時は赤字メッセージ + OK 無効化

### 右クリック・コンテキストメニュー
- **各 Session は、そのツールの主要機能を右クリックで呼び出せるようにする** (NSOutlineView など AppKit を直接使う Session は `menu(for:)` をオーバーライド、SwiftUI 主体の Session は `.contextMenu` モディファイアを使う)
- **右クリック位置の項目が未選択なら、まずその項目を選択してからメニューを表示する**
- メニュー項目はキーボードショートカットと 1:1 で対応させ、メニュー項目のタイトルに同じショートカット (`⏎` `⌘N` `⌫` 等) を併記する
- メニュー項目の有効/無効は現在の選択状態に応じて切り替える (`NSMenu.autoenablesItems = false` + 明示的な `isEnabled`)

### 選択・フォーカス
- **複数選択を許可する Session** では Shift+クリック / Shift+↑↓ を NSOutlineView / SwiftUI List の標準動作に任せる
- **新規作成・リネーム・移動など、結果として別のノードにフォーカスすべき操作の後は、明示的に新ノードを選択 + 可視スクロール + first responder 再設定**する
- フィルタ/検索/並び替えによる reloadData 後は、事前の選択状態を可能な限り復元する

## 参考
- [SPEC.md](./SPEC.md) — 仕様本体
- [decisions/](../decisions/README.md) — 設計判断の記録
