---
title: Active Session Switcher
description: Ctrl+Tab で表示する縦並びのセッション履歴切替ウィンドウ仕様 (macOS Cmd+Tab 風、activeSessionHistory を新しい順に表示)
derived_from:
  - docs/specs/sessions/active-session.md
syncs_with:
  - docs/specs/window/shortcuts.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-22
---

# Active Session Switcher

`Ctrl+Tab` で表示し、`SessionRegistry.activeSessionHistory` を新しい順に縦並びで提示する Session 切替ウィンドウ。macOS の `Cmd+Tab` (アプリ切替) と同じ操作感を狙う。

履歴データ自体の管理ルールは [sessions/active-session.md](../sessions/active-session.md) を参照。

---

## トリガーとキー操作

| キー | 動作 |
|---|---|
| **`Ctrl+Tab`** (初回) | ウィンドウを表示し、履歴の **2 番目** (= 直前のアクティブ Session) を選択した状態で開く |
| **`Ctrl+Tab`** (ウィンドウ表示中) | 選択を **古い方** (リストの下) へ 1 つ移動 |
| **`Shift+Ctrl+Tab`** | 選択を **新しい方** (リストの上) へ 1 つ移動 |
| **`Ctrl` リリース** | ウィンドウを閉じて、選択中の Session をアクティブ化する |

- `Ctrl` を押し続けている間はウィンドウ表示が継続する
- `Ctrl` を離した瞬間が確定タイミング
- **Esc / 外クリック等のキャンセル経路は提供しない** (常に Ctrl リリースで確定)
- 履歴が **0 / 1 件**しかない場合は表示しない (何もしない)

### 端での移動

- 一番下 (最古) で `Ctrl+Tab`: 何もしない (循環しない)
- 一番上 (最新) で `Shift+Ctrl+Tab`: 何もしない (循環しない)

---

## データソース

`SessionRegistry.activeSessionHistory: [SessionID]` を **逆順**で表示する。

履歴の不変条件 ([sessions/active-session.md](../sessions/active-session.md) で定義):

- 末尾が最新、先頭が最古
- 同一 SessionID は 1 度しか含まれない (重複排除)
- 最大 50 件 (古い方から自動破棄)
- Session が破棄 (タブクローズ) されたら履歴からも除去される
- **`workspace.json` (v5) に永続化される** ([persistence.md](../aspects/persistence.md#workspacejson-レイアウトsession-状態コンパニオンレコメンド統合))

→ 表示時に追加の重複排除や検証は不要。50 件全部を表示する (リストが長くなっても OK)。
→ アプリ再起動後も履歴が残るので、起動直後でも `Ctrl+Tab` で前回の作業中セッションへ戻れる。

---

## 表示

### レイアウト

- **borderless overlay window** (装飾なし、半透明背景)
- Window は **アクティブな Aidea Window の中央** に配置
- 縦並び (上から下へ、新しい順)

### 各エントリ

```
┌────────────────────────────────────┐
│ [icon]  Session 表示名             │  ← 選択中はアクセントカラー背景
├────────────────────────────────────┤
│ [icon]  Session 表示名             │
├────────────────────────────────────┤
│ ...                                │
└────────────────────────────────────┘
```

- **icon**: Session の Tool に対応する SF Symbol (Tool.systemImageName を流用)
- **Session 表示名**: Tab ヘッダの表示名と同じ規約
  - Filer: `"Files"` 等の Tool displayName
  - Preview: `state.title` 優先、なければ `state.url?.lastPathComponent`
  - Terminal / Claude: `displayName` + インスタンス番号など (要実装で確定)
  - 共通仕様は per-tool spec に従う
- 選択中エントリは **アクセントカラーで強調** (Filer の選択行と同等)

### 表示しないもの

- プレビュー / 詳細情報 (本文サムネイル等)
- スクロールバー (件数次第で表示するが、装飾はシンプルに)
- ペイン位置情報

---

## キー検出機構

`NSEvent.addLocalMonitorForEvents` を使う。Cmd+W 用の手法 ([ADR 0011](../../decisions/0011-cmd-w-via-nsevent-monitor.md)) と同じパターン。

### 監視対象

| イベント | 用途 |
|---|---|
| `.keyDown` | `Tab` キー (keyCode 48) + Control 修飾の有無 / Shift 修飾の有無を判定 |
| `.flagsChanged` | Control 修飾の押下/リリース検出 (リリースで確定) |

### ライフサイクル

1. **アプリ起動時**: keyDown モニターを 1 つ常駐させ、`Ctrl+Tab` を待つ
2. **`Ctrl+Tab` 検出**: ウィンドウ生成 + 表示 + 履歴 2 番目を選択。flagsChanged モニターを追加で登録
3. **ウィンドウ表示中**:
   - `Ctrl+Tab` / `Shift+Ctrl+Tab`: 選択移動
   - `flagsChanged` で Control が外れたら確定 → ウィンドウ破棄 + flagsChanged モニター解除 + `activateSession(selectedID)` 呼び出し
4. **その他のキー**: 表示中はすべて吸収する (no-op)。ウィンドウ非表示中は通常通り通過

---

## エッジケース

- **履歴が空 / 1 件**: ウィンドウ表示しない。Ctrl+Tab は no-op
- **履歴中の Session が既に破棄**: 既存の `destroySession` 内で履歴からも除去するため発生しない (本仕様で追加要件)
- **複数 Window**: 将来複数 Window 対応する場合、各 Window が独自の `activeSessionHistory` を持つ前提なので、Switcher も Window ごとに独立して動く (現状 1 Window のみ)
- **Session 切替中の表示**: アクティブ化アニメーション完了を待たずに Ctrl+Tab 連打しても、履歴更新と表示は同期的なので問題ない

---

## activeSessionHistory への追加要件

本機能の導入に合わせて、`SessionRegistry.destroySession(_:)` が呼ばれたとき (= タブクローズ時) に `activeSessionHistory` から該当 SessionID を削除する。

```swift
func destroySession(_ id: SessionID) {
    sessions.removeAll { $0.id == id }
    activeSessionHistory.removeAll { $0 == id }   // ← 新規追加
}
```

これにより:
- Switcher に「既に存在しない Session」が表示されない
- ユーザがタブを閉じた後の履歴が直感的になる
- 履歴選択 → アクティブ化時の "Session not found" エラーが起きない

---

## 関連

- [sessions/active-session.md](../sessions/active-session.md) — `activeSessionHistory` の定義と更新ルール
- [shortcuts.md](./shortcuts.md) — グローバルショートカット一覧
- [../aspects/keybindings.md](../aspects/keybindings.md) — 横断キーバインディング
- [ADR 0011](../../decisions/0011-cmd-w-via-nsevent-monitor.md) — NSEvent local monitor の参考前例
