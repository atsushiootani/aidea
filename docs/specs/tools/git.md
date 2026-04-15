# Tool 仕様: Git

Git の変更差分を閲覧・操作する Tool。変更があるファイルだけをツリー表示し、
ダブルクリックで GitDiff ツール (左右分割の差分表示) を開く。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/git.md](../sessions/git.md) / [sessions/git-diff.md](../sessions/git-diff.md) を参照。
共通 UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- **Window 全体で 1 つだけ**のシングルトン Session (Filer と同じ制約)
- `WorkspaceState.projectRoot` をリポジトリルートとして使用
- 2 つのモードをセグメントピッカーで切替:
  - **Working Changes**: `git diff` (ワーキングツリーの変更)
  - **PR Preview**: `git diff main...HEAD` (現在ブランチと main の差分)
- 変更があるファイルのみをディレクトリ構造でツリー表示
- ダブルクリック / Enter で **GitDiff ツール**を別ペインの新規タブに開く
- ステージング操作 (git add/reset) は MVP 範囲外

---

## Git ツール (メイン)

### モード

| モード | git コマンド | 表示内容 |
|---|---|---|
| **Working Changes** | `git diff --name-status` | ワーキングツリーの変更ファイル一覧 |
| **PR Preview** | `git diff main...HEAD --name-status` | main ブランチとの差分ファイル一覧 |

セグメントピッカーで切替。モードが変わったら一覧を再取得して表示更新。

### ファイル一覧

- NSOutlineView ベースのディレクトリツリー (Filer と同じ表示パターン)
- **変更のあるファイルだけ**を表示 (変更のないファイル/ディレクトリは非表示)
- 変更ディレクトリは変更ファイルを祖先に持つものだけ展開可能
- 各ファイルにステータスアイコン/バッジ:
  - `M` (Modified) — 変更
  - `A` (Added) — 新規
  - `D` (Deleted) — 削除
  - `R` (Renamed) — リネーム
- SF Symbols + 色でステータスを区別:
  - Modified: `pencil.circle` (黄色)
  - Added: `plus.circle` (緑)
  - Deleted: `minus.circle` (赤)
  - Renamed: `arrow.right.circle` (青)

### データ取得

```swift
// Working Changes
Process: git diff --name-status
// PR Preview
Process: git diff main...HEAD --name-status
```

出力パース例:
```
M	docs/README.md
A	Aidea/Aidea/NewFile.swift
D	old_file.txt
R100	old_name.swift	new_name.swift
```

### 自動更新

- FSEvents でプロジェクトルート配下を監視 (Filer と共有可能)
- `.git` 配下の変更検知でファイル一覧を再取得 (デバウンス 500ms)
- モード切替時も即座に再取得

---

## GitDiff ツール

Git ツールのファイル一覧からダブルクリック / Enter で開かれる。
ファイルごとに 1 つの GitDiff Session が作成され、別ペインの新規タブに表示される。

### 概要

- **マルチインスタンス可** (シングルトンではない。複数ファイルの diff を同時に開ける)
- ファイル名をパラメータとして受け取る
- WKWebView + [diff2html](https://diff2html.xyz/) で左右分割 (side-by-side) 表示
- シンタックスハイライト付き

### 表示内容

- **左側**: HEAD (コミット済み / main 側) のコード
- **右側**: Working Copy (現在のファイル / HEAD 側) のコード
- 変更行がハイライト (追加=緑, 削除=赤)
- ファイル名をタブタイトルに表示

### diff 取得

```swift
// Working Changes モードから開いた場合
Process: git diff <file>
// PR Preview モードから開いた場合
Process: git diff main...HEAD -- <file>
```

### diff2html 統合

WKWebView にラッパ HTML をロードし、`git diff` の出力を JavaScript 経由で diff2html に渡す:

```html
<script src="diff2html-bundle.min.js"></script>
<script>
const diffString = `<diff output from git>`;
const targetElement = document.getElementById('diff');
const configuration = {
    drawFileList: false,
    outputFormat: 'side-by-side',
    matching: 'lines',
    highlight: true,
};
const diff2htmlUi = new Diff2HtmlUI(targetElement, diffString, configuration);
diff2htmlUi.draw();
diff2htmlUi.highlightCode();
</script>
```

diff2html の JS/CSS は **オンライン CDN** (`https://cdn.jsdelivr.net/npm/diff2html/`) から取得。
(Aidea にバンドルしない。外部依存最小化方針 ADR 0006 との整合: diff2html は npm パッケージではなく
ブラウザランタイムで CDN から読み込むため Swift の外部依存には該当しない)

### discard 機能

ハンク (git の `@@` ブロック) 単位で変更を破棄できる。

#### UI
- diff 表示の各ハンク横に **「Discard」ボタン** (または右クリックメニュー)
- ボタン押下 → 確認ダイアログ (「このハンクの変更を破棄しますか？」OK / Cancel)

#### 実装
- `git diff <file>` のパッチ出力からハンクを抽出
- 対象ハンクを逆パッチ (`git apply --reverse`) でワーキングツリーに適用
  ```swift
  Process: echo "<reverse-patch>" | git apply --reverse
  ```
- 適用後、diff 表示を再取得して更新

#### 制約
- Working Changes モードのみ有効 (PR Preview では discard しない)
- ファイル全体の revert は MVP 範囲外 (`git checkout -- <file>` は将来)

---

## Tool 種別

issue #26 では 2 つの Tool が必要:

| Tool (enum case) | 名前 | シングルトン | 用途 |
|---|---|---|---|
| `.git` | Git | ✅ (1 つだけ) | 変更ファイル一覧 + モード切替 |
| `.gitDiff` | GitDiff | ❌ (複数可) | 個別ファイルの差分表示 + discard |

`Tool` enum に `.git` と `.gitDiff` を追加。

---

## キーボード操作

### Git ツール
| キー | 機能 |
|---|---|
| **Enter** | 選択ファイルの GitDiff を開く |
| **↑ / ↓** | ファイル選択移動 |
| **Ctrl + P / N** | Emacs ナビゲーション |
| **Cmd + F** | ファイル名検索 (将来) |

### GitDiff ツール
| キー | 機能 |
|---|---|
| **↑ / ↓** | スクロール |
| **Ctrl + P / N / V / Z** | スクロール (Emacs) |

---

## マウス操作

### Git ツール
| 操作 | 機能 |
|---|---|
| シングルクリック | ファイル選択 |
| ダブルクリック | GitDiff を別ペインの新規タブに開く |
| 右クリック | コンテキストメニュー (将来) |

---

## 受け入れ基準

### Git ツール
- [ ] Working Changes モードで `git diff --name-status` の結果がツリー表示される
- [ ] PR Preview モードで `git diff main...HEAD --name-status` の結果がツリー表示される
- [ ] セグメントピッカーでモード切替ができる
- [ ] 変更のあるファイルだけが表示される (変更なしは非表示)
- [ ] ファイルにステータスアイコン (M/A/D/R) が表示される
- [ ] ダブルクリック / Enter で GitDiff が別ペインに開く
- [ ] `.git` 配下の変更で自動更新される
- [ ] シングルトン制約: 2 つ目の Git ツールは `+` メニューに出ない

### GitDiff ツール
- [ ] diff2html で左右分割 (side-by-side) 表示される
- [ ] シンタックスハイライトが効く
- [ ] ハンクごとに Discard ボタンが表示される (Working Changes から開いた場合のみ)
- [ ] Discard → 確認ダイアログ → 変更が破棄される → diff が更新される
- [ ] 複数ファイルの GitDiff を同時に開ける

---

## 実装メモ

### 新規ファイル

```
Models/Git/
  GitChangedFile.swift       // ステータス (M/A/D/R) + パス + ツリーノード
  GitDiffContent.swift       // diff 出力テキスト + メタデータ

Services/Git/
  GitService.swift           // Process で git コマンド実行
  GitChangesLoader.swift     // diff --name-status → [GitChangedFile]

Sessions/Git/
  GitSessionState.swift      // モード + 変更ファイル一覧
  GitDiffSessionState.swift  // ファイルパス + diff コンテンツ + モード

Views/Sessions/Git/
  GitSessionView.swift       // NSOutlineView + セグメントピッカー
  GitDiffSessionView.swift   // WKWebView + diff2html + Discard ボタン
```

### Tool enum 追加

```swift
enum Tool {
    // 既存
    case filer, kit, terminal, web, preview
    // 追加
    case git       // シングルトン
    case gitDiff   // マルチインスタンス
}
```

### シングルトン制約
- Filer と同じく PaneView の `isAddable` で `.git` を条件付き非表示にする

### GitDiff の開き方
- Git ツールのダブルクリック → `registry.openPreview` と同じパターンだが、
  Preview ではなく GitDiff Session を作成する
- `registry.openGitDiff(for: filePath, mode: .workingChanges | .prPreview)`
  のような専用メソッドを SessionRegistry に追加

---

## 未検討事項 (将来)

- ステージング操作 (git add / git reset)
- コミット UI (メッセージ入力 + `git commit`)
- ブランチ切替 UI
- ファイル全体の revert (`git checkout -- <file>`)
- PR 作成 UI (`gh pr create`)
- 比較対象ブランチの変更 (main 以外)
- diff2html のオフラインバンドル
- Untracked files の表示
- ファイル名検索 (Cmd+F)
