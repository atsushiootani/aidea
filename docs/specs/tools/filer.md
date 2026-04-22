---
title: Tool 仕様: Filer
description: NSOutlineView ベースのディレクトリツリー・FSEvents 連動・複数選択対応の Filer Tool 仕様
derived_from:
  - docs/decisions/0009-nsoutlineview-and-fsevents.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
syncs_with:
  - docs/specs/sessions/filer.md
  - docs/specs/aspects/keybindings.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-22
---

# Tool 仕様: Filer

Filer Tool の機能仕様。実装は [`Aidea/Sessions/Filer/`](../../../Aidea/Aidea/Sessions/Filer/) と
[`Aidea/Views/Sessions/Filer/`](../../../Aidea/Aidea/Views/Sessions/Filer/) 配下。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/filer.md](../sessions/filer.md) を参照。
全ツール共通のコンテキストメニュー・ダイアログ規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- NSOutlineView ベースのディレクトリツリー
- **Window 全体で 1 つだけ**のシングルトン Session
- `WorkspaceState.projectRoot` をルートとして走査
- FSEvents による外部変更の自動反映 (デバウンス 200ms)
- SF Symbols で種類別アイコン
- **除外ルール**: デフォルト + ユーザ定義のパターンでファイル/ディレクトリを表示から除外 (詳細は [除外ルール](#除外ルール) 節)
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

### editExcludeRules — 除外ルールを編集
- ペイン上部の歯車ボタン (または検索バー横の設定アイコン) から「除外ルール設定...」ダイアログを開く
- 改行区切りで複数のパターンを編集できる `NSScrollView` 内の `NSTextView`
- ダイアログ下部に「デフォルトに戻す」ボタン (デフォルトリストで上書き)
- OK / Cancel ボタン。OK で `FilerSessionState.excludeRules` を更新し、即座に Filer 表示と検索を再評価する
- 適用後の状態は `workspace.json` に保存される (詳細は [除外ルール](#除外ルール) 節)

### openInFinder — Finder で開く
- **単一選択かつ非 root のときのみ**動作 (複数選択 / 選択なし / root 選択時は NSBeep して no-op)
- **ファイル**: 親フォルダを Finder で開き、該当ファイルを選択状態にする (`NSWorkspace.shared.activateFileViewerSelecting([url])`)
- **ディレクトリ**: そのフォルダ自体を Finder で開く (`NSWorkspace.shared.open(url)`)

### copySelected — クリップボードにコピー
- **複数選択対応**。選択中のファイル/ディレクトリを `NSPasteboard.general` に `NSPasteboard.PasteboardType.fileURL` 形式で書き込む
- projectRoot (ルート) 自身はコピー対象から除外
- 選択なし / projectRoot のみ選択時は NSBeep して no-op
- macOS 標準形式で書き込むため、**Finder / 他アプリと相互運用可能** (Finder でコピー → Aidea にペースト、Aidea でコピー → Finder にペースト のどちらも可)
- Aidea を閉じても pasteboard は OS 全体の領域なので残る

### pasteFromClipboard — クリップボードから貼り付け
- `NSPasteboard.general` から `NSPasteboard.PasteboardType.fileURL` を取得し、対象ディレクトリへ `FileManager.default.copyItem(at:to:)` で物理コピーする (ディレクトリは再帰コピー)
- pasteboard 上に `fileURL` 形式の URL が 0 件なら NSBeep して no-op
- **貼り付け先ディレクトリの決定ルール** ([createFile](#createfile--ファイル新規作成) と同じ):
  - **単一選択でディレクトリ** (root 含む): そのディレクトリ内
  - **単一選択でファイル**: その親ディレクトリ
  - 複数選択 or 選択なし: projectRoot 直下
- **同名衝突時のリネーム**: 末尾に `_N` を付ける (`N = 2, 3, 4, ...` と存在しない名前までインクリメント)
  - 拡張子あり (`foo.txt`): 拡張子の前に `_N` → `foo_2.txt` / `foo_3.txt` / ...
  - 拡張子なし (`README`): 末尾に `_N` → `README_2` / `README_3` / ...
  - ディレクトリ (`mydir`): 末尾に `_N` → `mydir_2` / `mydir_3` / ...
  - 判定は「貼り付け先ディレクトリにそのエントリ名のノードが存在するか」で行う (ファイル/ディレクトリの区別はしない)
- コピー元と貼り付け先が同じディレクトリのときも同じ規則で動く (必ず衝突するのでリネームが走る)
- 複数ファイル/ディレクトリのコピーは順に処理し、それぞれのエントリ単位で衝突判定する
- ペースト完了後、新しく作成されたエントリ群を選択状態にフォーカスする (drag&drop / createFile と同じパターン)
- エラー時 (権限なし / 容量不足 / コピー元が既に存在しない 等) は NSAlert で通知。1 件でも失敗した場合は `NSAlert(error:)` を上げ、成功分の選択フォーカスはそのまま適用する

### openWith — 指定のアプリケーションで開く
- **単一選択かつ非 root のときのみ**動作 (複数選択 / 選択なし / root 選択時は NSBeep して no-op)
- macOS 標準の「このアプリケーションで開く」と同じ **OS 由来の候補リスト**を提示する
  - 候補取得: `NSWorkspace.shared.urlsForApplications(toOpen: url)` (macOS 12+)
  - デフォルトアプリ取得: `NSWorkspace.shared.urlForApplication(toOpen: url)` (macOS 12+)
  - ファイル/ディレクトリ両対応 (URL ベース)
- 候補が 0 件でもメニューは表示する (末尾の「その他...」だけの構成になる)
- 候補項目を選ぶと `NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration:)` で起動
- **メニュー構成** (macOS Finder の「このアプリケーションで開く」に準拠):
  1. **デフォルトアプリ** (取得できた場合のみ): 先頭に「{アプリ名} (デフォルト)」として表示
  2. **区切り線** (デフォルトアプリがある場合のみ)
  3. **候補アプリ一覧**: デフォルトアプリと重複するエントリは除く。アルファベット順は OS API の並び順に従う
  4. **区切り線** (常に表示)
  5. **その他...**: `NSOpenPanel` を `/Applications` 起点で表示し、`UTType.application` のみ選択可。選択したアプリで `NSWorkspace.shared.open(...)` を呼ぶ
- **右クリックメニュー経由**: 「指定のアプリケーションで開く ▶」サブメニューに上記構成を展開
- **ショートカット (`⌃A`) 経由**: サブメニューと同じ構成を `NSMenu.popUp` で選択行の付近に表示する
  (サブメニュー経由と同じ構築関数を使い、UI 経路だけ切り替える)

### showContextMenu — 右クリックコンテキストメニュー
- 右クリック位置の行が選択されていなければ、その行を選択してからメニュー表示
- 表示項目 (選択状態に応じて有効/無効を切替):
  - **プレビューで開く** (`⏎`) — 選択がすべてファイルのとき有効
  - **名前を変更** (`⇧⏎`) — 単一選択かつ非 root のとき有効
  - **新規ファイル** (`⌘N`)
  - **新規ディレクトリ** (`⌘⇧N`)
  - **削除** (`⌫`) — 選択ありかつ非 root が含まれるとき有効
  - --- (区切り線) ---
  - **Finder で開く** (`⌃O`) — 単一選択かつ非 root のとき有効
  - **指定のアプリケーションで開く** (`⌃A`) ▶ — 単一選択かつ非 root のとき有効 (末尾に常に「その他...」があるため候補 0 件でも有効)
  - --- (区切り線) ---
  - **コピー** (`⌘C`) — 選択ありかつ非 root が含まれるとき有効
  - **ペースト** (`⌘V`) — クリップボードに `fileURL` 候補があり、貼り付け先ディレクトリが決定できるとき有効
  - --- (区切り線) ---
  - **除外ルール設定...** — `editExcludeRules` を開く
- 各項目はキーボード操作と 1:1 対応 (除外ルール設定は KB ショートカット無し)

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
| **Ctrl + O** | [openInFinder](#openinfinder--finder-で開く) |
| **Ctrl + A** | [openWith](#openwith--指定のアプリケーションで開く) |
| **Cmd + C** | [copySelected](#copyselected--クリップボードにコピー) |
| **Cmd + V** | [pasteFromClipboard](#pastefromclipboard--クリップボードから貼り付け) |
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

## 除外ルール

Filer の表示・検索からファイル/ディレクトリを除外するパターンの集合。

### 適用範囲

- **表示**: ルート展開時・ディレクトリ展開時に各エントリをマッチ判定し、ヒットしたエントリは出力しない
- **検索** (`searchByName`): 全 tree 走査時にも同じ判定を適用する。除外されたエントリは検索結果に出ない
- **表示と検索は完全に同じルールを参照する** (検索だけ・表示だけのバイパスは無い)

### パターン形式

`.gitignore` 風の glob パターンを採用:

| パターン | 意味 | 例 |
|---|---|---|
| `<basename>` | パスセパレータを含まない → 各エントリの **basename (lastPathComponent)** に対して glob match | `node_modules` `.DS_Store` |
| `<basename glob>` | 同上 + ワイルドカード `*` `?` 対応 | `*.swp` `tmp.*` `?ackup` |
| `<path>/<...>` | パスセパレータを含む → projectRoot からの **相対パスのプレフィックス** に対して glob match | `.claude/worktrees` `build/intermediates` |

- ワイルドカードは `*` (任意文字列) と `?` (任意 1 文字) のみ。`**` や `[...]` 等の高度な構文はサポートしない (将来拡張)
- 大文字小文字を区別する
- マッチ判定はエントリの種類 (ファイル/ディレクトリ) を区別しない (両方に同じパターンを適用)

### デフォルト除外ルール

```
.git
node_modules
DerivedData
.build
.DS_Store
.claude/worktrees
```

- 管理場所 (当面): `FilerSessionState.defaultExcludeRules` — Swift 側の定数
- 管理場所 (将来): #80 完了時に Bundle 内 `default-workspace.json` へ移管予定
- `.gitignore` に書かれた内容は**尊重しない** (除外ルールは Filer 専用設定で、git とは独立)

### 永続化

- 各 Filer Session が `excludeRules: [String]` を保持し、`workspace.json` (v4) に Filer Tab の状態として保存される
- 詳細は [../sessions/filer.md](../sessions/filer.md) と [../aspects/persistence.md](../aspects/persistence.md) を参照
- 新規 Filer Session 作成時 / v3→v4 マイグレーション時 / 「デフォルトに戻す」ボタン押下時には、`FilerSessionState.defaultExcludeRules` を参照する

### 編集

[editExcludeRules](#editexcluderules--除外ルールを編集) を参照。

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
- `openInFinder` / `openWith` の候補列挙は `NSWorkspace.shared.urlsForApplications(toOpen:)` (macOS 12+) を使用
- `openWith` のデフォルトアプリ解決は `NSWorkspace.shared.urlForApplication(toOpen:)` (macOS 12+) を使用
- `openWith` の「その他...」は `NSOpenPanel` に `allowedContentTypes = [UTType.application]`, `directoryURL = /Applications` を設定して表示
- `openWith` の右クリックサブメニューと Ctrl+A ポップアップは同一の `NSMenu` 構築関数を共用 (UI 経路のみ切替)
- `copySelected` は `NSPasteboard.general.clearContents()` → `writeObjects(urls as [NSURL])` で書き込む
- `pasteFromClipboard` は `NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])` で取得
- 衝突リネームは `nextAvailableURL(in:for:)` が `{base}_{N}{.ext}` を `N=2` から試し、存在しない名前が見つかるまでインクリメントして返す

---

## 未検討事項 (将来)

- **インライン編集への格上げ**: 現状は NSAlert ダイアログだが、本来の仕様 "セル内インライン編集" は未実装
- `.gitignore` を尊重する除外オプション (現状は除外ルール独自管理。`.gitignore` 連動はオプトインで将来検討)
- 除外ルールでの `**` (再帰グロブ) や `[abc]` (文字クラス) サポート
- fuzzy search (現状は substring マッチ)
- 検索結果の並び順 (マッチ度順?)
- 削除時に完全削除オプション (Shift+Backspace?)
- カット (Cmd+X) — 現状は Copy のみ。Cut は別 issue で検討
- 複数ノードの rename (batch rename)
