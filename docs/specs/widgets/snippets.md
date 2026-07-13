---
title: コードスニペット (Snippet)
description: よく使うシェルコマンドを登録し、ワンクリックで任意のターミナルセッションへ送信・実行する widget
derived_from:
  - docs/decisions/0033-snippet-scheduler-separation.md
  - docs/decisions/0034-scheduler-snippet-dispatch.md
syncs_with:
  - docs/specs/widgets/scheduler.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/aspects/persistence.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# コードスニペット (Snippet)

> よく使うシェルコマンドをワンクリックで任意のターミナルセッションへ送信・実行する widget

ヘッダ常駐 widget。スケジューラと異なり **トリガー・スケジュールの概念を持たない**。
ユーザーの認知モデルにおいてスケジューラとスニペットは別物であるため、
技術的には共通化できる部分があっても UI 上は独立して配置する ([ADR 0033](../../decisions/0033-snippet-scheduler-separation.md))。

スケジューラとの比較は [scheduler.md](./scheduler.md) を参照。

---

## スニペットモデル

各スニペットは次の要素だけを持つ (スケジューラより格段にシンプル)。

| フィールド | 型 | 既定値 | 意味 |
|---|---|---|---|
| `id` | string | （必須） | スニペット識別子 (一意) |
| `name` | string | （必須） | 表示名 |
| `command` | string | （必須） | ターミナルへ送信するコマンド文字列 (複数行可。各行がそのまま送信される) |
| `destination` | object | （省略可） | 既定の送信先。省略時は**アクティブ端末**。下記「送信先設定」参照 ([ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md)) |

有効 / 無効の概念は持たない (**常に有効**、issue #247)。旧フォーマットの `enabled` キーは読み込み時に無視される (未知キーを読み飛ばす後方互換)。

`destination`:

| キー | 型 | 意味 |
|---|---|---|
| `type` | string | `"tab"` / `"new"` |
| `title` | string | `tab` のとき必須。送信先タブ名 |

- `destination` 省略 = **アクティブ端末** (アクティブが Terminal ならそこ / 無ければ最初の Terminal / それも無ければ新規)。
- `{ "type": "tab", "title": "ログ" }` = タブ名「ログ」へ。無ければその名前で新規タブを作る (スケジューラと同じ解決。[ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md))。
- `{ "type": "new" }` = 常に新規タブ。

---

## 設定ファイル

```
.aidea/config/snippets.json
```

```json
{
  "snippets": [
    { "id": "dev-start", "name": "開発サーバ起動", "command": "npm run dev" },
    { "id": "test-run",  "name": "テスト実行",     "command": "npm test" }
  ]
}
```

ファイル不在は「スニペットなし」。
不正値 (id 空 / 重複 / name 空 / command 空) はログ警告でスキップする。

---

## 実行先の選択

スニペット実行は **「設定済みの送信先へ即実行」** と **「その場で別の端末を明示選択」** の 2 段構成 ([ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md))。

### 主ボタン (即実行)

スニペット行の主ボタンを押すと、選ばずに **`destination` 設定の送信先**へ送る。

| `destination` | 送信先 |
|---|---|
| 省略 (既定) | アクティブ端末 (アクティブが Terminal → そこ / 無ければ最初の Terminal / 無ければ新規) |
| `tab(title)` | タブ名 `title` のターミナル (無ければその名前で新規作成。スケジューラと同じ解決) |
| `new` | 常に新規タブ |

### メニュー (明示選択)

主ボタンの横のメニューから、**その場限り**で別の送信先に送れる（設定は変えない）。

| 選択肢 | 挙動 |
|---|---|
| アクティブターミナル | アクティブが Terminal → そこ。なければ最初の Terminal。無ければ新規 |
| 各ターミナルタブ (タブ名) | 開いている各ターミナルを**タブ名**で指定して送信。タブ名はタブの表示タイトル (ユーザーがリネームしたカスタム名、無ければ `Terminal N`) |
| 新規ターミナルタブ | 常に新規タブを作成して送信 |

スケジューラの terminal ジョブもタブ名で送信先を指定できる（[scheduler.md](./scheduler.md) / [ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md)）。違いは **スニペットは即時実行で「設定済み先 + その場選択」**、**スケジューラは自動発火で送信先を設定に永続化**する点。タブ名で既存ターミナルを狙える操作感・解決ロジックは両者で揃える。

---

## スケジューラとの相互変換 (ブリッジ)

変換は **移動 (元を削除)**。誤操作を防ぐため**確認ダイアログ**を挟む ([ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md))。

### スニペット → スケジューラへ昇格

スニペット行の「→ スケジューラ」ボタン:
- 確認後、トリガー = 手動 (`manual`) / 送信先 = `terminal` / プロンプト = スニペットの `command` のジョブとしてスケジューラに登録し、**元のスニペットを削除**する
- 送信先のマッピング: タブ名指定 (`tab` + `title`) → `terminal` の `sessionTitle: title` / 新規 (`new`) ・ アクティブ端末 (省略) → `terminal` の `sessionTitle` なし (新規)
- 追加後、ユーザはスケジューラ UI でトリガーを任意に変更できる

### スケジューラ → スニペットへ保存

スケジューラのジョブ行の「→ スニペット」ボタン:
- 確認後、ジョブの `prompt` を `command` としてスニペット登録し、**元のジョブを削除**する
- 送信先のマッピング: `terminal` の `sessionTitle: title` → タブ名指定 (`tab` + `title`) / `sessionTitle` なし → 新規 (`new`) / `claude` ジョブ → 既定 (アクティブ端末)
- スニペット側では trigger / 実行履歴の概念は持たない

---

## UI: スニペット widget (ヘッダ常駐)

[Widget 領域](./README.md#ui-配置原則-widget-領域) 内でスケジューラ widget の左隣に配置。

### ヘッダ表示

| 要素 | 内容 |
|---|---|
| アイコン | `curlybraces` (SF Symbol) |
| ラベル | スニペット件数 (0件なら「なし」) |
| ショートカット | ⌥⌘B |

### Popover: スニペット一覧

| 要素 | 内容 |
|---|---|
| タイトル | 「コードスニペット」＋「＋ 追加」ボタン |
| スニペット行 | name / **送信先 + command**（`→ 送信先 / command`。スケジューラ行と同形式）/ 実行ボタン(主)+メニュー / 編集 / 削除 / → スケジューラ |
| 削除ボタン | **確認ダイアログ**で確認してから削除する ([aspects/destructive-actions.md](../aspects/destructive-actions.md)、issue #247) |
| 実行ボタン (主) | 押すと `destination` 設定の送信先へ即送信。**アクセントカラー塗り + play アイコン**で、スケジューラの「今すぐ実行」(枠線のみ) より目立たせる (issue #247) |
| 実行メニュー | その場限りで別の端末を選択: アクティブターミナル / 各ターミナルタブ (タブ名)... / 新規ターミナルタブ |
| 空状態 | 「スニペットなし」 |

#### 編集フォーム

| フィールド | UI | 備考 |
|---|---|---|
| 名前 | テキスト入力 | 必須 |
| コマンド | **複数行テキスト入力** (等幅フォント、高さ約 5 行) | 必須。複数行コマンド可 (issue #247) |
| 送信先 | セグメント（既定(アクティブ) / タブ名 / 新規）+ タブ名入力 | タブ名選択時のみタブ名欄を表示。現在のタブ名をクイック選択でき、任意名も自由入力可 |

---

## 境界

### Always

- スニペット実行は Terminal のみ (Claude への送信は持たない)
- 主ボタンは設定済み送信先 (`destination`) へ即実行し、メニューでその場限りの別送信先を選べる
- `destination` のタブ名解決・同名フォールバックはスケジューラと同じ経路を使う
- 設定はファイル (`.aidea/config/snippets.json`) で宣言的に管理する
- 実行履歴・lastRun 管理は持たない (都度実行)
- スケジューラ⇄スニペットの変換は確認ダイアログ後に元を削除する (移動)
- スニペットの削除は確認ダイアログを経る ([aspects/destructive-actions.md](../aspects/destructive-actions.md))

### Never

- スケジュール機能 (定時 / 起動時) は持たない
- スケジューラと同一 config ファイルを共有しない
- 有効 / 無効トグルを持たない (常に有効。issue #247)

---

## 関連ドキュメント

- [ADR 0033](../../decisions/0033-snippet-scheduler-separation.md) — スニペットとスケジューラを分離した設計判断
- [scheduler.md](./scheduler.md) — スケジューラ (スニペットとの詳細比較)
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/config/` の配置
