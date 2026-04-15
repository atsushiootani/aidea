# Tool 仕様: Filer

Filer Tool の機能仕様。実装は [`Aidea/Sessions/Filer/`](../../../Aidea/Aidea/Sessions/Filer/) と
[`Aidea/Views/Sessions/Filer/`](../../../Aidea/Aidea/Views/Sessions/Filer/) 配下。

概念モデルは [sessions/concept-model.md](../sessions/concept-model.md) / [glossary.md](../glossary.md) を参照。
全ツール共通のコンテキストメニュー・ダイアログ規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- NSOutlineView ベースのディレクトリツリー
- **Window 全体で 1 つだけ**のシングルトン Session
- `WorkspaceState.projectRoot` をルートとして走査
- FSEvents による外部変更の自動反映 (デバウンス 200ms)
- SF Symbols で種類別アイコン
- 隠しファイル表示 (`.git` `node_modules` `DerivedData` `.build` `.DS_Store` のみ除外)
- **複数選択対応** (Shift+クリック / Shift+↑↓) — `allowsMultipleSelection = true`

---

## 機能

### openSelectedInPreview — プレビューで開く
- **単一選択**: ファイルなら新しい Preview Session を作成 (ダブルクリックと同等)、ディレクトリなら展開/折りたたみをトグル
- **複数選択**: 選択中のファイルすべてについて Preview Session を開く (ディレクトリは無視)
- 選択がなければ no-op

### renameSelected — 名前変更
- **単一選択時のみ**動作 (複数選択時は no-op)
- `FileNameInputDialog` (NSAlert ベース) を開いて現在の名前をプリセット
- 入力中に同じ親ディレクトリに同名のファイル/ディレクトリが存在する場合、
  **「同名のファイル・ディレクトリが存在します」と赤字で表示 + OK を無効化**
- 自分自身の名前と一致しているうちはエラー扱いしない
- Enter で確定 → `FileManager.default.moveItem(at:to:)` でリネーム
- 確定後、リネーム先にフォーカス (明示的な再取得 + 選択)
- projectRoot (ルート) 自身は変更不可

### createFile — ファイル新規作成
- 対象の親ディレクトリを決定する
  - **単一選択**でディレクトリならその中
  - **単一選択**でファイルならその親ディレクトリ
  - 複数選択 or 選択なし: projectRoot 直下
- **先に名前入力 UI を表示する** (`FileNameInputDialog`)
  - 入力中に同名があれば赤字エラー + OK 無効化 (renameSelected と同じ)
  - 空のまま確定しようとしたら何もせずキャンセル
- Enter 確定で空ファイルを作成 (`FileManager.default.createFile(atPath:contents:attributes:)`)
- 作成後、新ファイルにフォーカス (再取得 → 選択)
- Esc でキャンセル

### createDirectory — ディレクトリ新規作成
- 親ディレクトリの決定ルール・入力 UI・バリデーション・キャンセル挙動は [createFile](#createfile--ファイル新規作成) と同じ
- 確定時に空ディレクトリを作成 (`FileManager.default.createDirectory(at:withIntermediateDirectories:attributes:)`)

### deleteSelected — 選択ノードの削除 (複数対応)
- 選択中のファイル/ディレクトリをすべてゴミ箱に移動する
- **削除前に必ず確認ダイアログを表示**
  - 単一: "`<name>` を削除しますか？"
  - 複数: "X 個の項目を削除しますか？" + 名前を先頭 5 件まで表示
- ディレクトリの場合は配下ごと削除される旨をダイアログに明示
- 実装: `FileManager.default.trashItem(at:resultingItemURL:)` (完全削除しない)
- projectRoot 自身は削除対象から除外
- 削除したファイル/ディレクトリを表示していた **Preview Session タブは自動でクローズ**される
  (`SessionRegistry.closePreviewsForDeleted`)

### moveByDragAndDrop — ドラッグ&ドロップでファイル/ディレクトリを移動 (複数対応)
- ファイラ内のノードをドラッグして別のディレクトリにドロップするとファイルシステム上で移動する
- **ドロップターゲット**:
  - ディレクトリノード: その中に移動 (ドロップターゲットをハイライト)
  - ファイルノード: その親ディレクトリに移動
  - ルート (空白): projectRoot 直下に移動
- **同一親ディレクトリへのドロップは no-op**
- **自身 or その配下へのドロップは禁止** (循環防止)
- **同名ファイルが移動先にある場合は上書き確認ダイアログ** (Esc でキャンセル可)
- projectRoot 自身はドラッグできない
- 複数選択ノードも一括で移動可能
- 実装: `FileManager.default.moveItem(at:to:)`
- 移動元を表示していた Preview タブは自動クローズ
- 移動後は移動先ノードにフォーカス
- 外部アプリからのドロップ (Finder 等) も `.fileURL` 経由で受け入れる

### searchByName — ファイル名/ディレクトリ名のインクリメンタル検索
- ペイン上部に `NSSearchField` を表示 (通常は非表示)
- 入力するたびに全ツリーを走査し、名前に部分一致するノードとその祖先をフィルタ表示
  - ディレクトリの子ノードは必要に応じて遅延ロードされる
  - マッチしたディレクトリは自動展開される
- **マッチ文字をハイライト**: `NSMutableAttributedString` で黄色背景 + 太字を該当範囲に適用
- Esc で検索バーを閉じて通常表示に戻る (フォーカスがファイラ本体にあっても Esc で閉じる)
- 検索中に Enter → [openSelectedInPreview](#openselectedinpreview--プレビューで開く) 相当
- 再度 Cmd+F で検索バーの表示トグル

### showContextMenu — 右クリックコンテキストメニュー
- 右クリック位置の行が選択されていなければ、その行を選択してからメニュー表示
- 表示項目 (選択状態に応じて有効/無効を切替):
  - **プレビューで開く** (`⏎`) — 選択がすべてファイルのとき有効
  - **名前を変更** (`⇧⏎`) — 単一選択かつ非 root のとき有効
  - **新規ファイル** (`⌘N`)
  - **新規ディレクトリ** (`⌘⇧N`)
  - **削除** (`⌫`) — 選択ありかつ非 root が含まれるとき有効
- 各項目はキーボード操作と 1:1 対応

---

## キーボード操作

各キー入力を上記「機能」にマップする。

| キー | 機能 |
|---|---|
| **Enter** | [openSelectedInPreview](#openselectedinpreview--プレビューで開く) |
| **Shift + Enter** | [renameSelected](#renameselected--名前変更) |
| **Cmd + N** | [createFile](#createfile--ファイル新規作成) |
| **Cmd + Shift + N** | [createDirectory](#createdirectory--ディレクトリ新規作成) |
| **Backspace** | [deleteSelected](#deleteselected--選択ノードの削除-複数対応) |
| **Cmd + F** | [searchByName](#searchbyname--ファイル名ディレクトリ名のインクリメンタル検索) |
| **Esc** | 検索バーが開いていれば閉じる (`searchByName` のキャンセル) |
| **Shift + ↑ / ↓** | 選択範囲の拡張 (NSOutlineView 標準) |
| **Ctrl + P / N / F / B** | Emacs ライクナビゲーション ([共通ルール](../sessions/ui-rules.md#キーボードナビゲーション-emacs-ライク) を参照)。Ctrl+V/Z (ページ送り) は Filer では無効 |

---

## マウス操作

| 操作 | 機能 |
|---|---|
| シングルクリック | ノード選択 |
| Shift + クリック | 選択範囲の拡張 |
| Cmd + クリック | 選択の追加/削除 |
| ダブルクリック (ファイル) | [openSelectedInPreview](#openselectedinpreview--プレビューで開く) |
| ダブルクリック (ディレクトリ) | 展開/折りたたみトグル |
| ディスクロージャ三角形クリック | 展開/折りたたみトグル |
| ドラッグ&ドロップ | [moveByDragAndDrop](#movebydraganddrop--ドラッグドロップでファイルディレクトリを移動-複数対応) |
| 右クリック | [showContextMenu](#showcontextmenu--右クリックコンテキストメニュー) |

---

## 受け入れ基準 (Acceptance Criteria)

### openSelectedInPreview
- [x] ファイル選択中に Enter → Preview Session が開く
- [x] ディレクトリ選択中に Enter → 展開/折りたたみ
- [x] 複数選択中にファイルのみすべて Preview で開かれる
- [x] 選択なしで Enter → 何も起きない

### renameSelected
- [x] 単一選択時、ダイアログが現在名プリセットで開く
- [x] 同名があれば赤字エラー + OK 無効化
- [x] 自分自身の名前はエラーにならない
- [x] 確定で moveItem、成功後に新位置にフォーカス
- [x] Esc でキャンセル
- [x] projectRoot 自身は変更不可
- [x] 複数選択時は no-op

### createFile / createDirectory
- [x] ダイアログが空の入力で開く
- [x] Enter で入力名のファイル/ディレクトリを作成
- [x] Esc でキャンセル (何も作られない)
- [x] 空入力での確定はキャンセル扱い
- [x] 同名時は赤字エラー + OK 無効化
- [x] 作成後、新ノードにフォーカス

### deleteSelected
- [x] 選択に応じた確認ダイアログが表示される (単一/複数)
- [x] OK でゴミ箱へ移動される
- [x] Esc / キャンセルで何も起きない
- [x] ディレクトリは配下ごと削除される旨を明示
- [x] 削除後に該当 Preview タブが自動で閉じる
- [x] projectRoot は削除されない

### moveByDragAndDrop
- [x] ノードをドラッグして別ディレクトリにドロップで移動される
- [x] ファイルノードにドロップすると親ディレクトリに移動する
- [x] 同一親へのドロップは no-op
- [x] 自身/配下へのドロップは禁止
- [x] 同名がある場合、上書き確認ダイアログが出る
- [x] 複数選択ノードを一括で移動できる
- [x] projectRoot はドラッグできない
- [x] 移動後に FSEvents でツリーが更新され、新位置にフォーカス

### searchByName
- [x] Cmd+F で検索バーが現れてフォーカス
- [x] 入力のたびにフィルタが効く (incremental)
- [x] マッチ文字がハイライト表示される
- [x] マッチ結果の親ディレクトリが展開された状態で表示される
- [x] Esc (検索フィールド / ファイラ本体 どちらでも) で閉じる
- [x] 検索中 Enter → Preview で開ける

### showContextMenu
- [x] 右クリックでメニューが出る
- [x] クリック位置の行が未選択なら選択してから表示
- [x] 選択状態に応じて項目の有効/無効が切り替わる

---

## 実装メモ

- キー入力は `FilerOutlineView` (NSOutlineView サブクラス) の `keyDown(with:)` で拾う
- 右クリックメニューは `FilerOutlineView.menu(for:)` をオーバーライドしてコントローラの `buildContextMenu()` を呼ぶ
- 名前変更・新規作成は `FileNameInputDialog` (NSAlert ベース) に集約。リアルタイム重複チェックは
  `NSControl.textDidChangeNotification` を監視し、`NameInputValidator` が OK ボタンと赤字ラベルを更新する
- 削除は `FileManager.default.trashItem(at:resultingItemURL:)` でゴミ箱行き
- 確認ダイアログは `NSAlert` (`.warning` style、Cancel ボタンに `keyEquivalent = "\u{1b}"` を明示)
- ドラッグ&ドロップは `NSOutlineViewDataSource` の `pasteboardWriterForItem` / `validateDrop` / `acceptDrop` で実装。
  ペイロードは `NSURL`、受け取りは `.fileURL` 経由
- 検索バーは `NSSearchField`。`NSStackView` で outlineView の上に配置、通常は `isHidden = true`
- 検索フィルタは `filteredRoots: [FileTreeNode]` + `filteredChildren: [ObjectIdentifier: [FileTreeNode]]`
  に蓄積し、データソースメソッドが `isSearching` 中はこれを参照する (元の rootNodes は破壊しない)
- マッチハイライトは `NSMutableAttributedString` で背景色 (`.systemYellow.withAlphaComponent(0.6)`) と
  太字フォントを該当範囲に適用

---

## 未検討事項 (将来)

- **インライン編集への格上げ**: 現状は NSAlert ダイアログだが、本来の仕様 "セル内インライン編集" は未実装
- `.gitignore` を尊重する除外オプション
- fuzzy search (現状は substring マッチ)
- 検索結果の並び順 (マッチ度順?)
- 削除時に完全削除オプション (Shift+Backspace?)
- 外部アプリからファイルコピー (現状は move のみ)
- コピー&ペースト (Cmd+C / Cmd+V)
- 複数ノードの rename (batch rename)
