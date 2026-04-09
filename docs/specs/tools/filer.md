# Tool 仕様: Filer

Filer Tool の機能仕様。実装は [`Aidea/Sessions/Filer/`](../../../Aidea/Aidea/Sessions/Filer/) と
[`Aidea/Views/Sessions/Filer/`](../../../Aidea/Aidea/Views/Sessions/Filer/) 配下。

概念モデルは [SPEC.md](../SPEC.md#2-概念モデル-concept-model) / [glossary.md](../glossary.md) を参照。

---

## 概要

- NSOutlineView ベースのディレクトリツリー
- **Window 全体で 1 つだけ**のシングルトン Session
- `WorkspaceState.projectRoot` をルートとして走査
- FSEvents による外部変更の自動反映 (デバウンス 200ms)
- SF Symbols で種類別アイコン
- 隠しファイル表示 (`.git` `node_modules` `DerivedData` `.build` `.DS_Store` のみ除外)

---

## 機能

### openSelectedInPreview — プレビューで開く
- 選択中のノードがファイルなら、アクティブ Session 履歴に基づいて新しい Preview Session を作成 (ダブルクリックと同等)
- ディレクトリなら展開/折りたたみをトグル
- 選択がなければ no-op

### renameSelected — 名前変更
- 選択中のノード (ファイル/ディレクトリ) の名前を編集モードに
- インライン編集 (NSOutlineView のセル内で `NSTextField` を編集可能化)
- Enter で確定、Esc でキャンセル
- 同名が既にあればエラーダイアログ
- projectRoot (ルート) 自体は変更不可

### createFile — ファイル新規作成
- 対象の親ディレクトリを決定する
  - 選択がディレクトリならその中
  - 選択がファイルならその親ディレクトリ
  - 選択がなければ projectRoot 直下
- **先に名前入力 UI を表示する** (renameSelected と同じインライン入力 UI を、空のプレースホルダ行として表示)
  - 入力中に同じ親ディレクトリに同名のファイル/ディレクトリが存在する場合、
    入力欄の下に **「同名のファイル・ディレクトリが存在します」と赤字で表示**し、
    **OK (Enter) を押せないように無効化**する
  - 入力が空のまま確定しようとした場合は何もせずキャンセル (= Esc と同じ)
- Enter で確定したタイミングで、入力された名前のファイルを作成 (空ファイル)
- Esc でキャンセル (ファイルは作られない)
- 実装: `FileManager.default.createFile(atPath:contents:attributes:)`

### createDirectory — ディレクトリ新規作成
- 親ディレクトリの決定ルール・入力 UI・バリデーション・キャンセル挙動は [createFile](#createfile--ファイル新規作成) と同じ
- 確定時にディレクトリを作成
- 実装: `FileManager.default.createDirectory(at:withIntermediateDirectories:attributes:)`

### deleteSelected — 選択ノードの削除
- 選択中のノード (ファイル/ディレクトリ) を削除する
- **削除前に必ず確認ダイアログを表示** ("`<name>` を削除しますか？" / OK / Cancel)
- ディレクトリの場合は配下ごと削除されることを明示
- `FileManager.default.trashItem(at:resultingItemURL:)` を使い、ゴミ箱に入れる (完全削除しない)
- projectRoot 自身は削除不可
- 選択なしでは no-op

### moveByDragAndDrop — ドラッグ&ドロップでファイル/ディレクトリを移動
- ファイラ内のノードをドラッグして別のディレクトリにドロップすると、ファイルシステム上で移動する
- **ドロップターゲット**:
  - ディレクトリノード: その中に移動 (ドロップターゲットをハイライト)
  - ファイルノード: その親ディレクトリに移動
  - ルート (何もない空白): projectRoot 直下に移動
- **同一親ディレクトリへのドロップは no-op**
- **同名ファイルが移動先にある場合は上書き確認ダイアログ** ("`<name>` は既に存在します。上書きしますか？" / OK / Cancel)
- projectRoot 自身はドラッグできない
- 複数ノードのドラッグは MVP 範囲外 (単一ノードのみ)
- 実装: `FileManager.default.moveItem(at:to:)`
- 外部アプリからのドロップ (Finder 等) は将来検討

### searchByName — ファイル名/ディレクトリ名のインクリメンタル検索
- Filer ペイン上部にインライン検索バーを表示
- 入力するたびに NSOutlineView をフィルタ (名前に部分一致するノードのみ表示)
- 親ディレクトリは暗黙に展開される (マッチする子孫を持つディレクトリも表示)
- **1 文字ごとにマッチ文字をハイライト**: マッチした文字部分を背景色 or 太字で強調
  - VS Code / Fuzzy Finder 系の UI 慣習
  - 単純な substring マッチでも fuzzy マッチでも OK (MVP は substring)
- Esc で検索バーを閉じて通常表示に戻る
- 検索中でも他のキーボード操作 (Enter / Shift+Enter 等) は有効

---

## キーボード操作

各キー入力を上記「機能」にマップする。

| キー | 機能 |
|---|---|
| **Enter** | [openSelectedInPreview](#openselectedinpreview--プレビューで開く) |
| **Shift + Enter** | [renameSelected](#renameselected--名前変更) |
| **Cmd + N** | [createFile](#createfile--ファイル新規作成) |
| **Cmd + Shift + N** | [createDirectory](#createdirectory--ディレクトリ新規作成) |
| **Backspace** | [deleteSelected](#deleteselected--選択ノードの削除) |
| **Cmd + F** | [searchByName](#searchbyname--ファイル名ディレクトリ名のインクリメンタル検索) |

---

## マウス操作

後日追記予定。現状の実装は以下:

| 操作 | 機能 |
|---|---|
| シングルクリック | ノード選択 (ハイライトのみ) |
| ダブルクリック (ファイル) | [openSelectedInPreview](#openselectedinpreview--プレビューで開く) |
| ダブルクリック (ディレクトリ) | 展開/折りたたみトグル |
| ディスクロージャ三角形クリック | 展開/折りたたみトグル |
| ドラッグ&ドロップ | [moveByDragAndDrop](#movebydraganddrop--ドラッグドロップでファイルディレクトリを移動) |

---

## 受け入れ基準 (Acceptance Criteria)

### openSelectedInPreview
- [ ] ファイル選択中に Enter → Preview Session が開く (ダブルクリックと同じ挙動)
- [ ] ディレクトリ選択中に Enter → 展開/折りたたみが切り替わる
- [ ] 選択なしで Enter → 何も起きない

### renameSelected
- [ ] 選択中の名前がセル内で編集モードになる
- [ ] Enter で確定、ファイルシステム上のファイル名が変わる
- [ ] Esc で編集キャンセル、元の名前に戻る
- [ ] 同名エラー時にダイアログ表示
- [ ] projectRoot ノード自身には適用されない

### createFile / createDirectory
- [ ] 実行時に空の入力プレースホルダ行が表示される
- [ ] Enter 押下で入力された名前のファイル/ディレクトリが作成される
- [ ] Esc でキャンセルできる (何も作られない)
- [ ] 入力が空のまま確定しようとすると何もせずキャンセルされる
- [ ] 同名ファイル/ディレクトリがある場合、赤字のエラーメッセージが表示される
- [ ] エラー状態では OK (Enter) が無効化される
- [ ] 作成後 FSEvents 経由でツリーが即座に更新される

### deleteSelected
- [ ] Backspace で確認ダイアログが表示される
- [ ] OK を押すとゴミ箱に移動される
- [ ] Cancel で何も起きない
- [ ] ディレクトリの場合は配下ごと削除される旨がダイアログに表示される
- [ ] projectRoot は削除されない

### moveByDragAndDrop
- [ ] ノードをドラッグして別ディレクトリにドロップでファイルシステム上移動される
- [ ] ドロップターゲットがハイライトされる
- [ ] ファイルノードにドロップしたら親ディレクトリに移動する
- [ ] 同一親へのドロップは no-op
- [ ] 同名ファイルがある場合、上書き確認ダイアログが出る
- [ ] projectRoot はドラッグできない
- [ ] 移動後、FSEvents でツリーが即座に更新される

### searchByName
- [ ] ペイン上部に検索バーが現れてフォーカスされる
- [ ] 入力するたびにフィルタが効く (incremental)
- [ ] マッチ文字がハイライト表示される
- [ ] マッチ結果の親ディレクトリが展開された状態で表示される
- [ ] Esc で検索バーが閉じる
- [ ] 検索中に Enter → その行を preview で開ける

---

## 実装メモ

- NSOutlineView のキー入力は `NSResponder.keyDown(with:)` で拾う
- 名前変更は `NSTextField.isEditable = true` + `NSTableCellView` のフォーカス切替
- 新規作成は `FileManager.default.createFile(atPath:contents:attributes:)` / `createDirectory(at:withIntermediateDirectories:attributes:)`
- 削除は `FileManager.default.trashItem(at:resultingItemURL:)` でゴミ箱行き
- ドラッグ&ドロップは NSOutlineView の `NSDraggingSource` / `NSDraggingDestination` プロトコルで実装。`FileManager.default.moveItem(at:to:)` でファイルシステム操作
- 確認ダイアログは `NSAlert` (`.warning` style、OK / Cancel ボタン)
- 検索バーは SwiftUI の `TextField` を FilerSessionView の上に重ねる形で実装
- マッチハイライトは `NSMutableAttributedString` で背景色/太字を指定し、NSTableCellView の textField に渡す
- 検索中のフィルタは FileTreeNode を別配列にマッピングするか、`isVisible: Bool` フラグを足す

---

## 未検討事項 (将来)

- 複数選択操作
- ドラッグ&ドロップでの移動/コピー
- 右クリックコンテキストメニュー
- `.gitignore` を尊重する除外オプション
- fuzzy search (現状は substring マッチ)
- 検索結果の並び順 (マッチ度順?)
- 削除時に完全削除オプション (Shift+Backspace?)
