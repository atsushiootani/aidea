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
  - docs/specs/aspects/sort-order.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-03
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
- **ソート順**: ファイル/ディレクトリを区別せず名前のアルファベット順で混在表示 (詳細は [ソート順](#ソート順) 節)
- **除外ルール**: デフォルト + ユーザ定義のパターンでファイル/ディレクトリを表示から除外 (詳細は [除外ルール](#除外ルール) 節)
- **シンボリックリンク**: ディレクトリへのリンクも展開可能 (詳細は [シンボリックリンク](#シンボリックリンク-issue-119) 節)
- **複数選択対応** (Shift+クリック / Shift+↑↓) — `allowsMultipleSelection = true`

---

## ソート順

各ディレクトリ直下のエントリは、**ファイル/ディレクトリを区別せず名前順で混在表示する** (issue #122)。

比較ルール・共通ヘルパは [aspects/sort-order.md](../aspects/sort-order.md) に集約 (Finder 互換の `String.localizedStandardCompare`)。
Filer の表示順がワークスペース全体 (Git / Kit 等) の List UI のソート基準となる。

### Filer 固有の適用範囲

- ルート展開時・ディレクトリ展開時の通常表示
- [searchByName](#searchbyname--ファイル名ディレクトリ名のインクリメンタル検索) のフィルタ結果も同じ比較で並べる
- アンドゥ後の再描画・FSEvents による自動再読み込み後も同じ規則を適用

### 実装箇所

- `Services/Filer/FileTreeLoader.swift` の `load(directory:parent:)` — 子エントリ取得直後に `String.naturalAscending` でソート

---

## シンボリックリンク (issue #119)

ディレクトリへのシンボリックリンクを **通常のディレクトリと同じように展開・操作できる**。
主な用途は `quickmemo/` のような外部ディレクトリへのリンクをプロジェクトルート直下に置き、Filer から扱うこと。

### 判定

- `FileTreeLoader.load(directory:parent:)` は各エントリ取得時に `URLResourceKey.isSymbolicLinkKey` も合わせて取得する
- **シンボリックリンクの場合**: リンクの解決先 (`URL.resolvingSymlinksInPath()`) に対して `URLResourceKey.isDirectoryKey` を再評価し、解決先がディレクトリなら `FileTreeNode.isDirectory = true` とする
- **解決先がファイル**: `isDirectory = false` (= 通常のファイルとして扱う)
- **broken link (解決先が存在しない)**: `isDirectory = false` の通常ファイル扱い (展開不可)
- **通常のファイル/ディレクトリ**: 従来どおり `isDirectoryKey` のみで判定

### UI

- アイコン・装飾は **通常のディレクトリ/ファイルと同じ** (リンクを示す badge / 装飾は付けない)
- ディレクトリリンクならディスクロージャ三角形が表示され、展開操作で配下を読み込める
- ソート・検索・除外ルール・デコレーションも通常のディレクトリ/ファイルと同じ規則を適用

### 展開時の挙動

- リンクの URL をそのまま `contentsOfDirectory(at:)` に渡すと `ENOTDIR (NSPOSIXError 20)` で空配列になるため、
  **`FileTreeLoader.load(directory:parent:)` 内でディレクトリ URL がシンボリックリンクのときは解決先パスへ切り替えて読み込む**
- 取得した各エントリは **リンク経由のパス** に付け替えて `FileTreeNode.url` を生成する (例: 親が `<projectRoot>/quickmemo` のリンクなら子は `<projectRoot>/quickmemo/foo.md`)
- これにより `expandedURLs: Set<URL>` にもリンク経由のパスが保存され、再起動後の永続化と整合する

### 循環リンクの防止

- 展開時に「リンクの解決先 (`url.resolvingSymlinksInPath().standardizedFileURL`)」を計算し、**祖先チェーン内に同一の解決先パスがあれば展開を no-op とする** (beep もしない)
- 自分自身を含む先祖を指すリンクや、`a → b → a` のような相互リンクを安全にスキップする
- 判定対象は「自ノード自身がシンボリックリンク」のときのみ (通常ディレクトリは循環し得ないため毎回チェックは不要)

### 操作系

- **rename / delete / move (D&D) / copy / paste**: いずれも **リンクそのもの** を対象に動作する (実体には影響しない)
- `FileManager.default.moveItem` / `trashItem` / `copyItem` のいずれもデフォルトでリンクを link として扱うので追加実装は不要
- ユーザは「普通のディレクトリと同じ感覚で操作する。実体に波及しないことだけが違う」位置づけ

### Finder / 外部アプリで開く

- `openInFinder` / `openWith` は `NSWorkspace.shared.activateFileViewerSelecting([url])` / `NSWorkspace.shared.open(url)` をそのまま使う (OS がリンクを解決して挙動を決める)

### 境界

- **Always**: ディレクトリへのシンボリックリンクは展開可能なディレクトリとして扱う
- **Always**: 操作系 (rename / delete / move / copy) はリンク自体を対象とする (実体には触れない)
- **Never**: ディレクトリリンクの祖先チェーン内に同一解決先がある場合は展開しない (循環防止)
- **Never**: リンクであることをアイコン・色・badge で区別表示しない (issue #119 の方針「区別せず扱いたい」)

### 実装箇所

- `Services/Filer/FileTreeLoader.swift` — `isSymbolicLinkKey` 取得 + 解決先の `isDirectoryKey` 再評価
- `Views/Sessions/Filer/FileTreeViewController.swift` (展開系) — シンボリックリンク自身についてのみ祖先解決先チェックを実施し、循環時は展開を抑止

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

### dragToTabSlot — タブスロットへのドラッグでプレビューを開く
- ファイラ内のファイルをドラッグして [TabSlot](../glossary.md#ui-階層-5-階層モデル) にドロップすると、そのスロット位置に新規 Preview Session を挿入する
- **対象はファイルのみ**: ディレクトリをドラッグしている場合は TabSlot 側が accept せず、ドロップ不可の見た目になる
- **複数選択**: 選択順にスロット位置から連続挿入 (`index`, `index+1`, `index+2`, ...)
- **既存 Preview の dedupe**: 既に同じ URL の Preview タブがあれば **そのタブをアクティブ化するだけ** で、スロット位置への移動は行わない ([sessions/active-session.md#preview-を開くときの呼び出し規約](../sessions/active-session.md#preview-を開くときの呼び出し規約) の dedupe ルールを継承)
- **外部アプリ (Finder 等) からのドロップも受け入れる** (`.fileURL` 経由で同じ経路を通る)
- 実装は `SessionRegistry.openPreviewAtSlot(for:pane:index:title:)` 経由
- projectRoot 自身はドラッグ対象にならない (既存の制約と同じ)

### undoLastOperation — 直前の Filer 操作を取り消す / やり直す
- **対象操作**: [renameSelected](#renameselected--名前変更) / [createFile](#createfile--ファイル新規作成) / [createDirectory](#createdirectory--ディレクトリ新規作成) / [deleteSelected](#deleteselected--選択ノードの削除-複数対応) / [moveByDragAndDrop](#movebydraganddrop--ドラッグドロップでファイルディレクトリを移動-複数対応) / [pasteFromClipboard](#pastefromclipboard--クリップボードから貼り付け)
- **対象外**: [copySelected](#copyselected--クリップボードにコピー) (副作用なし) / [openSelectedInPreview](#openselectedinpreview--プレビューで開く) / [openInFinder](#openinfinder--finder-で開く) / [openWith](#openwith--指定のアプリケーションで開く) / [editExcludeRules](#editexcluderules--除外ルールを編集) (設定変更はアンドゥ対象外)
- **キー**: `⌘ Z` (undo) / `⌘ ⇧ Z` (redo)
- **スコープ**: **Filer Session 専用**。Window 内に Filer は singleton なので実質 Window 全体だが、他ツールの操作 (Terminal 入力 / Claude 送信 等) とは独立した履歴を持つ
- **アンドゥの実装方針**:
  - **rename**: 旧名→新名を記録し、`FileManager.moveItem(at:to:)` で逆方向に rename
  - **move (ドラッグ&ドロップ含む)**: 旧 URL→新 URL を記録し、`moveItem(at:to:)` で元位置に戻す
  - **delete**: `trashItem(at:resultingItemURL:)` で取得した **ゴミ箱内 URL** を保存し、アンドゥ時は `moveItem(at: trashURL, to: originalURL)` で復元
  - **createFile / createDirectory**: 作成した URL を `trashItem` でゴミ箱送り (アンドゥ後に再 redo すると元の URL に戻す)
  - **pasteFromClipboard**: 貼り付けで作成された URL 群を `trashItem` でゴミ箱送り
- **複数選択操作のグループ化**: 「N 件をまとめて削除/移動/ペースト」は `beginUndoGrouping` / `endUndoGrouping` で 1 グループにまとめ、**1 回の Cmd+Z で全件まとめて戻る**
- **redo**: `registerUndo` の中でさらに `registerUndo` する標準パターンで自動的に対応
- **履歴の深さ**: 無制限 (NSUndoManager のデフォルト)
- **永続化なし**: 履歴はメモリ上のみ。Window を閉じる / Filer Session を破棄すると失われる (`workspace.json` には保存しない)
- **エラー時の扱い**:
  - 復元先に同名ファイルが既に存在する / 権限が無い / ゴミ箱内 URL が既に消えている等の場合は NSAlert で通知
  - **当該 1 件のみ復元失敗として扱い、履歴自体は失効させない**。同じグループ内の他のエントリは引き続き復元を試み、後続の `⌘ Z` で別操作に遡れる
  - 部分的にしか復元できなかったグループでも履歴は前進する (失敗分の再試行は提供しない)
- **Preview タブとの連携**: アンドゥで復元されたファイルが Preview に紐付くタブがあった場合の挙動は変えない (削除時の自動クローズと同じく `closePreviewsForDeleted` 経路に乗せず、復元 = 再オープンの扱いはユーザ次第)

### searchByName — ファイル名/ディレクトリ名のインクリメンタル検索
- ペイン上部に `NSSearchField` を表示 (通常は非表示)
- 入力するたびに全ツリーを走査し、名前に部分一致するノードとその祖先をフィルタ表示
  - ディレクトリの子ノードは必要に応じて遅延ロードされる
  - マッチしたディレクトリは自動展開される
- **マッチ文字をハイライト**: `NSMutableAttributedString` で黄色背景 + 太字を該当範囲に適用
- Esc で検索バーを閉じて通常表示に戻る (フォーカスがファイラ本体にあっても Esc で閉じる)
- 検索中に Enter → [openSelectedInPreview](#openselectedinpreview--プレビューで開く) 相当
- 再度 Cmd+F で検索バーの表示トグル

### pageMoveSelection — ページ単位の選択移動 (issue #121)
- **キー**: `Page Up` / `Ctrl + Z` (上方向) / `Page Down` / `Ctrl + V` (下方向)
- **動作**: 1 ページ分 (= ビュー高さ ÷ 行高さ で切り捨てた行数。最低 1) だけ選択行を進める/戻す。スクロールも合わせて追従する
- **端の処理**: 端を超える場合は先頭/末尾の行で停止 (循環しない)
- **選択がない状態**: PageDown は先頭行、PageUp は末尾行を選択 (`Ctrl + N` / `Ctrl + P` の初期動作と同じ)
- **複数選択中**: 単一選択にリセットしてからページ移動 (アンカーは保持しない)
- **検索バー (searchByName) でフィルタ中**: 表示中 (フィルタ後) の行集合を対象に同じロジック
- **共通 Emacs ライクナビゲーションとの違い**: [共通ルール](../sessions/ui-rules.md#キーボードナビゲーション-emacs-ライク) の Ctrl+V/Z は「スクロールのみ」だが、Filer は選択カーソルも追従する独自拡張 (リスト/ツリーで選択カーソル概念を持つため)

### applyDecorations — ファイル/ディレクトリの装飾を適用
- 各エントリのアイコン (SF Symbol) と **行全体の背景色** を [デコレーション](#デコレーション) 節のルールに従って装飾する
- マッチングは「デフォルトデコレーション → ユーザデコレーション」を順に評価し、**後勝ち** (リスト後方ほど高優先) で `icon` と `color` を合成する
- 検索結果のマッチハイライト (黄色背景) は背景色より優先する (重ねて表示)

### editDecorationRules — デコレーションルールを編集
- ペイン上部の歯車メニュー (除外ルールと同じ歯車) から「デコレーションルール...」ダイアログを開く
- NSTableView ベースのエディタで、各行に **パターン** / **アイコン (SF Symbol)** / **色** の 3 列を表示
- 行末の「+追加」で新規追加、各行の「−」で削除
- **行を上下にドラッグして並べ替え可能** (NSTableView の D&D)。順序がマッチングの優先順位に直結し、後ろにあるルールほど高優先 (後勝ち)
- アイコン列のセルをクリックすると **推奨 SF Symbol 10〜20 個のグリッド + 「その他...」** ポップアップを表示
  - 「その他...」を選ぶと SF Symbol 名を文字列で直接入力できる小ダイアログを開く (`NSImage(systemSymbolName:)` で実在チェック)
- 色列のセルをクリックすると **推奨色プリセット + 「カスタム...」** ポップアップを表示
  - 「カスタム...」を選ぶと `NSColorPanel` から自由に色を指定できる (hex 形式で保存)
- OK で `FilerSessionState.userDecorationRules` を更新し、即座に Filer 表示を再描画
- 永続化される (`workspace.json` v6)

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
  - **デコレーションルール...** — `editDecorationRules` を開く
- 各項目はキーボード操作と 1:1 対応 (除外ルール設定 / デコレーションルールは KB ショートカット無し)

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
| **Cmd + Z** | [undoLastOperation](#undolastoperation--直前の-filer-操作を取り消す--やり直す) (アンドゥ) |
| **Cmd + Shift + Z** | [undoLastOperation](#undolastoperation--直前の-filer-操作を取り消す--やり直す) (リドゥ) |
| **Esc** | 検索バーが開いていれば閉じる (`searchByName` のキャンセル) |
| **Shift + ↑ / ↓** | 選択範囲の拡張 (NSOutlineView 標準) |
| **Page Up** / **Ctrl + Z** | [pageMoveSelection](#pagemoveselection--ページ単位の選択移動-issue-121) (上方向) |
| **Page Down** / **Ctrl + V** | [pageMoveSelection](#pagemoveselection--ページ単位の選択移動-issue-121) (下方向) |
| **Ctrl + P / N / F / B** | Emacs ライクナビゲーション ([共通ルール](../sessions/ui-rules.md#キーボードナビゲーション-emacs-ライク) を参照) |

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
| ドラッグ&ドロップ (ディレクトリ / 空白) | [moveByDragAndDrop](#movebydraganddrop--ドラッグドロップでファイルディレクトリを移動-複数対応) |
| ドラッグ&ドロップ (タブスロット) | [dragToTabSlot](#dragtotabslot--タブスロットへのドラッグでプレビューを開く) |
| 右クリック | [showContextMenu](#showcontextmenu--右クリックコンテキストメニュー) |

---

## デコレーション

ファイル/ディレクトリの **アイコン (SF Symbol)** と **行全体の背景色** を、glob パターンマッチで自由に指定する仕組み。

### 適用範囲

- **アイコン**: NSOutlineView セルの `imageView` に SF Symbol を表示 (`NSImage(systemSymbolName:)`)。指定がなければデフォルトデコレーション (拡張子別) のアイコンを使う
- **背景色**: NSOutlineView 行全体に背景塗りを適用 (`NSTableRowView.backgroundColor`)。指定がなければ無装飾
- 検索結果マッチハイライト (黄色背景) はデコレーション背景色より優先 (上に重ねて表示)
- 選択行のシステム標準ハイライトは AppKit に任せる (デコレーション背景色は選択時に上書きされる)

### パターン形式

[除外ルールのパターン形式](#パターン形式) と完全に同じ glob を採用 (`*` / `?` / `<basename>` / `<path>/<...>`、大小区別、ファイル/ディレクトリ非区別)。
ディレクトリ自身に対しても適用可能 (例: `node_modules` でディレクトリそのものを装飾)。

### マッチングルール

複数のルールにマッチした場合は **後勝ち** (配列の後方ほど高優先)。

- 評価順: `defaultDecorationRules` → `userDecorationRules` の順に連結した 1 本の配列を上から評価
- マッチした全ルールを順に合成し、`icon` / `color` ともに **最後にマッチしたルールの値** を使う
  - 後ろのルールが `icon: nil` を持つ場合は前のルールの `icon` を引き継ぐ (色も同様)
- これにより「特定ディレクトリ全体に薄い色 → さらに特定ファイルだけ強調色」のスタイルが書ける

### DecorationRule 構造

| 要素 | 型 | 用途 | 省略時 |
|---|---|---|---|
| `pattern` | String | glob パターン (除外ルール形式) | (必須) |
| `icon` | String? | SF Symbol 名 / 一部 Asset 名 (`drawio` 等) | 前のルールの値 or 標準アイコン |
| `color` | String? | 色名 (推奨プリセットのキー) または hex `#RRGGBB` | 前のルールの値 or 無装飾 |

### 推奨 SF Symbol

`DecorationIconPresets.recommended: [String]` (約 10〜20 個) を Aidea が定義。
編集 UI のアイコン列ポップアップで先頭にグリッド表示する。
末尾の「その他...」を選ぶと SF Symbol 名を直接タイプする小ダイアログを開き、任意の SF Symbol を指定可能 (`NSImage(systemSymbolName:)` で実在チェックして無効なら赤字表示)。

候補例: `swift` / `doc.text` / `doc.richtext` / `photo` / `terminal` / `gear` / `flame` / `star` / `bolt` / `paperplane` / `leaf` / `sparkles` / `cube` / `paintbrush` / `wrench.and.screwdriver` / `book` / `chart.bar` / `globe` / `ant` / `tag`

### 推奨色

`DecorationColorPresets.recommended: [(name, NSColor)]` (約 10 色)。
編集 UI の色列ポップアップで先頭にスウォッチ表示する。
「カスタム...」を選ぶと `NSColorPanel` から自由に色を指定可能 (内部で hex 文字列に正規化して保存)。

候補例: 黄 / 橙 / 赤 / ピンク / 紫 / 青 / 水色 / 緑 / 茶 / グレー
**背景色は systemColor を `alpha 0.2` 程度に薄めて適用** (テキストの可読性を確保)。

### デフォルトデコレーション

現状コードの `FileTreeLoader.iconName(for:)` 拡張子マッピングを **デフォルトデコレーション (`defaultDecorationRules`)** として明示的に表現する。

| パターン | アイコン (SF Symbol) | 色 |
|---|---|---|
| `*` (全ファイル) | `doc` | — |
| `*.swift` | `swift` | — |
| `*.md` / `*.markdown` | `doc.text` | — |
| `*.json` / `*.yaml` / `*.yml` | `doc.badge.gearshape` | — |
| `*.png` / `*.jpg` / `*.jpeg` / `*.gif` / `*.heic` / `*.webp` | `photo` | — |
| `*.pdf` | `doc.richtext` | — |
| `*.zip` / `*.tar` / `*.gz` | `doc.zipper` | — |
| `*.sh` / `*.zsh` / `*.bash` | `terminal` | — |
| `*.drawio` / `*.drawio.svg` | (Asset `drawio`) | — |

ディレクトリ (`folder`) は `node.isDirectory` 判定で別途決まり、`*` フォールバック以前に適用する (= デコレーションリストに含めず実装側で先に解決)。

色は全てなし (デフォルトは無装飾)。**ユーザは `userDecorationRules` を編集するだけで、デフォルト分は触らない** (Aidea 本体のアップデートで進化する)。

- 管理場所 (当面): `FilerSessionState.defaultDecorationRules` — Swift 側の定数
- 管理場所 (将来): #80 完了時に Bundle 内 `default-workspace.json` へ移管予定

### 永続化

各 Filer Session が **`userDecorationRules: [DecorationRule]`** (ユーザ追加分のみ) を保持し、`workspace.json` (v6) に Filer Tab の状態として保存される。
`defaultDecorationRules` は Aidea 同梱の定数なので **永続化しない**。
詳細は [../sessions/filer.md](../sessions/filer.md) と [../aspects/persistence.md](../aspects/persistence.md) を参照。

### 編集

[editDecorationRules](#editdecorationrules--デコレーションルールを編集) を参照。

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
- デコレーション解決は `DecorationMatcher` (除外ルールの `ExcludeMatcher` と同じ glob 実装を再利用) でファイル/ディレクトリ → 適用ルール群を取り出し、後勝ちで `icon` / `color` を合成する
- 描画は `outlineView(_:viewFor:)` で `imageView` のアイコン + tint を、`outlineView(_:rowViewForItem:)` で `NSTableRowView.backgroundColor` を設定する。`color` は hex 文字列を `NSColor` に復元したうえで `alpha 0.2` を掛けて適用する
- `DecorationRulesDialog` は `NSTableView` ベースで、編集中は内部に `[DecorationRule]` を持ち OK 確定で `FilerSessionState.userDecorationRules` を上書きする (除外ルールと同じパターン)
- 行 D&D 並べ替えは独自 pasteboard type `jp.ruri.aidea.decoration-row` を使い、`pasteboardWriterForRow` / `validateDrop` (`.above` のみ accept) / `acceptDrop` で `[DecorationRule]` の要素を移動する
- 行内のアイコン / 色 ポップアップは NSAlert モーダル中でも selection event が届くよう `NSMenu.popUpContextMenu(_:with:for:)` (NSEvent ベース) で表示する。`menu.popUp(positioning:at:in:)` 経路は NSAlert モーダル下では target/action 配信が走らず handler が呼ばれないため不可
- アンドゥは `FilerSessionState.undoManager: UndoManager` で管理。各操作 (rename / move / delete / create / paste) が成功した時点で `registerUndo(withTarget:handler:)` で逆操作を登録する。複数選択操作は `beginUndoGrouping` / `endUndoGrouping` で 1 グループにまとめる
- Cmd+Z / Cmd+Shift+Z は **`AideaApp.registerKeyEventMonitor` の `NSEvent.addLocalMonitorForEvents` で先取り**し、active session が `filer` のときだけ `FilerSessionState.undoManager.undo()` / `redo()` を呼ぶ。SwiftUI の Edit メニューは `@Environment(\.undoManager)` を見て AppKit 側 `NSResponder.undoManager` を見ないため、`performKeyEquivalent` 段階で disabled 判定 → beep を起こされる前にイベントを横取りする必要がある
- ページ移動 ([pageMoveSelection](#pagemoveselection--ページ単位の選択移動-issue-121)) は `FilerOutlineView.keyDown(with:)` 内で **PageUp / PageDown / Ctrl+V / Ctrl+Z** を捕捉する。1 ページの行数は `enclosingScrollView?.contentView.bounds.height / rowHeight` を Int 化 (最低 1) して算出し、`max(0, min(numberOfRows - 1, current ± pageRows))` でクランプして `selectRowIndexes(_:byExtendingSelection: false)` + `scrollRowToVisible(_:)` を呼ぶ
- 共通の `EmacsNavigation.handle` は `allowPageNav: false` のままとし、Ctrl+V/Z は Filer 側で独自処理する (共通ヘルパは selection 追従の概念を持たないため、Filer 拡張版として上書きする方針)

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
- デコレーション編集 UI の SF Symbol ビジュアル picker (現状は推奨グリッド + 文字列入力。NSCollectionView ベースの全件検索 picker は将来 issue)
- デコレーションのインポート / エクスポート / プロジェクト間共有
- デコレーション色の濃淡 / 太字テキスト / アイコンサイズ等の追加スタイル要素
