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

### Preview を開くときの規約

ファイル/リソースを Preview Session として開くときは、必ず `SessionRegistry.openPreview(for:title:)` を使う。
呼び出し側 (Filer / Kit / 他) は以下を守ること:

1. **呼び出し前に `registry.activeSessionID = <自分の SessionID>` を設定する**
   (openPreview はアクティブ Session のペインを「呼び出し元ペイン」として扱い、そのペインを避けて新しい Preview タブを配置するため)
2. **表示名がファイル名と異なる場合は `title` パラメータを渡す**
   (例: Kit の Skill は `title: "diagram.architecture"`、ファイル名 `SKILL.md` にしたくない場合)
3. 同じファイルの Preview が既に存在する場合は **新規作成せずそのタブをアクティブ化**する
   (openPreview が内部で dedupe する)
4. Preview タブが配置されるペインは以下のルールで決まる:
   - アクティブ履歴を新しい順にたどり、呼び出し元ペイン **以外** に属していた最新 Session のペインに配置
   - 該当がなければ呼び出し元ペイン以外の最初のペインにフォールバック

### キーボードナビゲーション (Emacs ライク)
リスト/ツリーを扱うすべての Session は、以下のキーバインディングを必ずサポートする。

| キー | 動作 | マップ先 |
|---|---|---|
| **Ctrl + P** | 上へ移動 | `moveUp` |
| **Ctrl + N** | 下へ移動 | `moveDown` |
| **Ctrl + F** | 右へ移動 | `moveRight` |
| **Ctrl + B** | 左へ移動 | `moveLeft` |
| **Ctrl + V** | ページダウン | `pageDown` |
| **Ctrl + Z** | ページアップ | `pageUp` |

実装は `Aidea/Utilities/EmacsNavigation.swift` の `EmacsNavigation.handle(event:responder:)`
を使う。NSOutlineView / NSTableView サブクラスは `keyDown(with:)` 内で以下のように呼び出す:

```swift
if EmacsNavigation.handle(event: event, responder: self) { return }
```

SwiftUI 主体の Session も同等のショートカットを提供する (将来 `onKeyPress` で実装)。

### タブ / ペイン / ツール操作 (グローバルショートカット)
どの Tool にフォーカスしていても共通で効く、アプリ全体のナビゲーション系ショートカット。
`AideaApp.body.commands` の `CommandMenu("タブ")` / `CommandMenu("ツール")` で実装する。

#### タブ・ペイン操作

| キー | 動作 |
|---|---|
| **⌘ T** | 新しいタブを追加 (NSAlert ベースの Tool 選択ダイアログを開く) |
| **⌘ W** | 現在のタブを閉じる。全タブ消滅時はペインも削除 |
| **⌘ ⇧ [** | 現在ペイン内で左のタブへ (ラップ) |
| **⌘ ⇧ ]** | 現在ペイン内で右のタブへ (ラップ) |
| **⌘ [** | 前のペインへ (ラップ) |
| **⌘ ]** | 次のペインへ (ラップ) |
| **⌘ ⇧ →** | 現在のペインを左右に分割 |
| **⌘ ⇧ ↓** | 現在のペインを上下に分割 |

#### ツール切替 (インスタンスの循環フォーカス)
現在アクティブ Session が同じ Tool なら **次のインスタンスに循環**、違う場合は最初のマッチに移動する。

| キー | Tool |
|---|---|
| **⌘ 1** | Filer |
| **⌘ 2** | Kit |
| **⌘ 8** | Terminal |
| **⌘ 9** | Web |
| **⌘ 0** | Preview |

#### 実装上の注意
- tree ミューテーション (`splitLeaf` / `removeLeaf`) は `DispatchQueue.main.async` で
  次 runloop に遅延させて SwiftUI の update サイクル外で実行する
  (さもないと `AttributeGraph precondition failure: setting value during update` でクラッシュ)
- ヘルパー `currentPane()` / `leafNode(for:)` で `activeSessionID` から対応する `Pane` / `LayoutNode` を逆引きする
- Filer はシングルトン制約があるため、⌘T の Tool 選択肢からは既存時に除外する

## 参考
- [SPEC.md](./SPEC.md) — 仕様本体
- [decisions/](../decisions/README.md) — 設計判断の記録
