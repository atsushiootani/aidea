# 概念モデル (Concept Model)

Aidea の UI は **Window / Pane / Tab / Session / Tool** という 5 つの概念で構成される。

```
Window
 └─ Pane (リサイズ可能な物理区画。HSplitView/VSplitView でツリー状)
     └─ Tab (ペイン内の表示切替単位。1 つの Session を参照する)
         └─ Session (1 つの実体。Window 全体で一意。状態を持つ)
              └─ Tool (機能種別。複数の Session が同じ Tool を共有しうる)
```

用語の定義は [../glossary.md](../glossary.md) を参照。
アクティブ Session の切替・履歴・Filer ダブルクリック時の挙動は [active-session.md](./active-session.md) を参照。

---

## Session ごとの内部状態

各 Tool の Session は固有の状態を持ち、**ペイン移動で失われない**よう `SessionState` として切り出す。

| Tool | `SessionState` の内容 | ペイン移動で保持 |
|---|---|---|
| `filer` | `FileTreeViewController` (展開・選択)・`selectedFile` | ✅ |
| `skills` | `SkillsLoader` + 選択 + グループ開閉 | ✅ |
| `commands` | `CommandsLoader` + 選択 + グループ開閉 | ✅ |
| `mcps` | `McpLoader` + 選択 | ✅ |
| `terminal` | `LocalProcessTerminalView` キャッシュ (PTY 含む) | ✅ |
| `web` | `WKWebView` キャッシュ + 現在 URL | ✅ |
| `preview` | `url: URL?` | ✅ |

---

## シングルトン制約

- **Filer Tool は Window 全体で 1 つだけ** (UI の `+` メニューで条件付き非表示)
- 他の Tool は同一 Window 内に複数インスタンス可
