# Session 内部状態: Preview

`preview` Tool の Session は `PreviewSessionState` (`@Observable`) として状態を保持する。
ファイル/リソースを NSTextView / NSImage / WebView (drawio) で表示する。

Tool 仕様は [../tools/preview.md](../tools/preview.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `url` | `URL?` | プレビュー中のファイル URL | ✅ |
| `title` | `String?` | タブ表示名 (Kit からの `diagram.architecture` 等) | ✅ |
| `session` | `Session?` (ObservationIgnored weak) | 自 Session への参照 | — |
| `pendingActivation` | `Bool` (ObservationIgnored) | `focusableView` 遅延セット時のアクティブ化保留フラグ | — |

## 開き方の規約

Preview は `SessionRegistry.openPreview(for:title:)` 経由で開く。
呼び出し側の義務 (activeSessionID の事前設定・title 指定・dedupe) は [active-session.md#preview-を開くときの呼び出し規約](./active-session.md#preview-を開くときの呼び出し規約) を参照。

## 永続化

`url` と `title` は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。
