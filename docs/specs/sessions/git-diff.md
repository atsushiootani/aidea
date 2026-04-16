# Session 内部状態: GitDiff

`gitDiff` Tool の Session は `GitDiffSessionState` (`@Observable`) として状態を保持する。
Git ツール経由で開かれる差分ビュー (diff2html レンダリング)。

Tool 仕様の背景は [../tools/git.md](../tools/git.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
diff2html の採用理由は [ADR 0004](../../decisions/0004-git-diff-with-diff2html.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `mode` | `GitMode` (`.workingChanges` / `.prPreview`) | 対応する Git ツールのモード | ✅ |
| `diffOutput` | `String` | `git diff` の生出力 | ✅ |
| `scrollToFile` | `String?` | 指定ファイルへスクロール指示 | — |
| `viewedFiles` | `Set<String>` | 既読ファイル集合 (変更時 `onViewedChanged` 発火) | ✅ |
| `focusedFile` | `String?` | フォーカス中のファイル | ✅ |
| `registry` | `weak var SessionRegistry?` | Git セッションへの逆参照 | — |

## 追加制約

`gitDiff` は `PaneView` の `+` メニューに載らず、**Git ツール経由でしか開けない**。
詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。
