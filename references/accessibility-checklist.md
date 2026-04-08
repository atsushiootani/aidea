# アクセシビリティチェックリスト

WCAG 2.1 AA 準拠のためのクイックリファレンス。`frontend-ui-engineering` スキルと併用してください。

## 目次

- [必須チェック](#必須チェック)
- [よくある HTML パターン](#よくある-html-パターン)
- [テストツール](#テストツール)
- [クイックリファレンス: ARIA ライブリージョン](#クイックリファレンス-aria-ライブリージョン)
- [よくあるアンチパターン](#よくあるアンチパターン)

## 必須チェック

### キーボードナビゲーション
- [ ] すべてのインタラクティブ要素が Tab キーでフォーカス可能
- [ ] フォーカス順序が視覚的/論理的順序に従う
- [ ] フォーカスが視認可能（アウトライン/リング）
- [ ] カスタムウィジェットにキーボードサポート（Enter で作動、Escape で閉じる）
- [ ] キーボードトラップがない（どこからでも Tab で離脱できる）
- [ ] ページ先頭にスキップリンク
- [ ] モーダルは開いている間フォーカスをトラップし、閉じた時にフォーカスを戻す

### スクリーンリーダー
- [ ] すべての画像に `alt` テキスト（装飾画像は `alt=""`）
- [ ] すべてのフォーム入力にラベルが関連付けられている（`<label>` または `aria-label`）
- [ ] ボタンやリンクに説明的テキスト（"Click here" ではなく）
- [ ] アイコンのみのボタンに `aria-label`
- [ ] ページに `<h1>` が1つ、見出しレベルがスキップされない
- [ ] 動的な内容変更がアナウンスされる（`aria-live` リージョン）
- [ ] テーブルに scope 付きの `<th>` ヘッダ

### 視覚
- [ ] テキストコントラスト比 ≥ 4.5:1（通常テキスト）または ≥ 3:1（大きいテキスト、18px 以上）
- [ ] UI コンポーネントと背景のコントラスト比 ≥ 3:1
- [ ] 色のみで情報を伝えない
- [ ] テキストを 200% に拡大してもレイアウトが崩れない
- [ ] 1秒あたり3回を超える点滅がない

### フォーム
- [ ] すべての入力に視認可能なラベル
- [ ] 必須フィールドが色のみに頼らず示される
- [ ] エラーメッセージは具体的でフィールドに関連付けられている
- [ ] エラー状態が色以外でも分かる（アイコン、テキスト、境界線）
- [ ] 送信エラーが集約表示されフォーカス可能

### コンテンツ
- [ ] 言語指定（`<html lang="en">`）
- [ ] ページに説明的な `<title>`
- [ ] リンクが周囲テキストと色以外でも区別できる
- [ ] モバイルのタッチターゲット ≥ 44x44px
- [ ] 意味のある空状態（空白画面ではない）

## よくある HTML パターン

### ボタンとリンク

```html
<!-- アクションには <button> を使う -->
<button onClick={handleDelete}>Delete Task</button>

<!-- ナビゲーションには <a> を使う -->
<a href="/tasks/123">View Task</a>

<!-- div/span をボタンとして使ってはいけない -->
<div onClick={handleDelete}>Delete</div>  <!-- BAD -->
```

### フォームラベル

```html
<!-- 明示的なラベル関連付け -->
<label htmlFor="email">Email address</label>
<input id="email" type="email" required />

<!-- 暗黙的なラップ -->
<label>
  Email address
  <input type="email" required />
</label>

<!-- 隠しラベル（可視ラベルが望ましい） -->
<input type="search" aria-label="Search tasks" />
```

### ARIA ロール

```html
<!-- ナビゲーション -->
<nav aria-label="Main navigation">...</nav>
<nav aria-label="Footer links">...</nav>

<!-- ステータスメッセージ -->
<div role="status" aria-live="polite">Task saved</div>

<!-- アラートメッセージ -->
<div role="alert">Error: Title is required</div>

<!-- モーダルダイアログ -->
<dialog aria-modal="true" aria-labelledby="dialog-title">
  <h2 id="dialog-title">Confirm Delete</h2>
  ...
</dialog>

<!-- ローディング状態 -->
<div aria-busy="true" aria-label="Loading tasks">
  <Spinner />
</div>
```

### アクセシブルなリスト

```html
<ul role="list" aria-label="Tasks">
  <li>
    <input type="checkbox" id="task-1" aria-label="Complete: Buy groceries" />
    <label htmlFor="task-1">Buy groceries</label>
  </li>
</ul>
```

## テストツール

```bash
# 自動監査
npx axe-core          # プログラム的なアクセシビリティテスト
npx pa11y             # CLI アクセシビリティチェッカー

# ブラウザ内
# Chrome DevTools → Lighthouse → Accessibility
# Chrome DevTools → Elements → Accessibility tree

# スクリーンリーダーテスト
# macOS: VoiceOver (Cmd + F5)
# Windows: NVDA (free) or JAWS
# Linux: Orca
```

## クイックリファレンス: ARIA ライブリージョン

| 値 | 挙動 | 用途 |
|-------|----------|---------|
| `aria-live="polite"` | 次の無音時にアナウンス | ステータス更新、保存確認 |
| `aria-live="assertive"` | 即座にアナウンス | エラー、時間的制約のあるアラート |
| `role="status"` | `polite` と同じ | ステータスメッセージ |
| `role="alert"` | `assertive` と同じ | エラーメッセージ |

## よくあるアンチパターン

| アンチパターン | 問題 | 修正 |
|---|---|---|
| `div` をボタンに | フォーカス不可、キーボード未対応 | `<button>` を使う |
| `alt` テキスト不足 | 画像がスクリーンリーダーに見えない | 説明的な `alt` を追加 |
| 色のみの状態 | 色覚異常ユーザーに見えない | アイコン、テキスト、模様を追加 |
| 自動再生メディア | 混乱を招き停止できない | コントロールを追加、自動再生しない |
| ARIA なしのカスタムドロップダウン | キーボード/SR で使えない | ネイティブ `<select>` または適切な ARIA listbox |
| フォーカスアウトライン削除 | 現在位置が分からない | アウトラインをスタイルする、削除しない |
| 空のリンク/ボタン | 説明なしで「リンク」とアナウンス | テキストや `aria-label` を追加 |
| `tabindex > 0` | 自然な Tab 順を壊す | `tabindex="0"` または `-1` のみ使用 |
