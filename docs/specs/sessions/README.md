# Session

Aidea の **Session 概念** に関する仕様を集約。
Session とは何かの用語定義は [../glossary.md](../glossary.md) を参照。

## 横断ドキュメント

| ファイル | 内容 |
|---|---|
| [ui-rules.md](./ui-rules.md) | 5 概念モデル / シングルトン制約 / 右クリック / 選択・フォーカス / Emacs ナビ |
| [active-session.md](./active-session.md) | アクティブ Session の切替・履歴 (50 件) ・Filer ダブルクリック時の挙動・Preview 開き規約 |

## Tool ごとの SessionState

各 Tool の `SessionState` 実装 (保持プロパティ・ペイン移動での保持・永続化) を 1 ファイルに記述。

| ファイル | SessionState クラス |
|---|---|
| [filer.md](./filer.md) | `FilerSessionState` |
| [kit.md](./kit.md) | `KitSessionState` |
| [terminal.md](./terminal.md) | `TerminalSessionState` |
| [claude.md](./claude.md) | `ClaudeSessionState` |
| [web.md](./web.md) | `WebSessionState` |
| [preview.md](./preview.md) | `PreviewSessionState` |
| [git.md](./git.md) | `GitSessionState` |
| [git-diff.md](./git-diff.md) | `GitDiffSessionState` |
