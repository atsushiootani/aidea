---
title: コードスニペット (Snippet)
description: よく使うシェルコマンドを登録し、ワンクリックで任意のターミナルセッションへ送信・実行する widget
derived_from:
  - docs/decisions/0033-snippet-scheduler-separation.md
syncs_with:
  - docs/specs/widgets/scheduler.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/aspects/persistence.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-16
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
| `command` | string | （必須） | ターミナルへ送信するコマンド文字列 |
| `enabled` | bool | `true` | 有効 / 無効 |

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

スニペット実行時に送信先ターミナルセッションを選べる。

| 選択肢 | 挙動 |
|---|---|
| アクティブターミナル | アクティブセッションが Terminal → そこへ送信。なければ開いている最初の Terminal。それも無ければ新規タブを作成 |
| Terminal N | 開いている特定のターミナルセッションを指定して送信 |
| 新規ターミナルタブ | 常に新規タブを作成して送信 |

スケジューラの terminal ジョブは「常に新規タブ」固定。スニペットはこの点が異なる。

---

## スケジューラとの相互変換 (ブリッジ)

### スニペット → スケジューラへ昇格

`SnippetRowView` の「→ スケジューラ」ボタン:
- `trigger: .manual, target: .terminal, prompt: snippet.command` のジョブを `SchedulerState.addJob()` で登録
- 追加後、ユーザはスケジューラ UI でトリガーを任意に変更できる

### スケジューラ → スニペットへ保存

`SchedulerRowView` の「→ スニペット」ボタン:
- ジョブの `prompt` を `command` としてスニペット登録
- スニペット側では trigger / 実行履歴の概念は持たない

---

## UI: SnippetView (ヘッダ常駐 widget)

`WidgetView` 内で `SchedulerView` の左隣に配置。

### ヘッダ表示

| 要素 | 内容 |
|---|---|
| アイコン | `curlybraces` (SF Symbol) |
| ラベル | 有効スニペット件数 (0件なら「なし」) |
| ショートカット | ⌥⌘B |

### Popover: SnippetPopoverView

| 要素 | 内容 |
|---|---|
| タイトル | 「コードスニペット」＋「＋ 追加」ボタン |
| スニペット行 | name / command / 実行 Menu / 編集 / 削除 / → スケジューラ / ON/OFF |
| 実行 Menu | アクティブターミナル / Terminal N... / 新規ターミナルタブ |
| 空状態 | 「スニペットなし」 |

#### 編集フォーム: SnippetEditView

| フィールド | UI | 備考 |
|---|---|---|
| 名前 | テキスト入力 | 必須 |
| コマンド | テキスト入力 (monospaced) | 必須 |
| 有効 | トグル | |

---

## 境界

### Always

- スニペット実行は Terminal のみ (Claude への送信は持たない)
- 実行先を毎回選択できる (アクティブ / 特定セッション / 新規)
- 設定はファイル (`.aidea/config/snippets.json`) で宣言的に管理する
- 実行履歴・lastRun 管理は持たない (都度実行)

### Never

- スケジュール機能 (定時 / 起動時) は持たない
- スケジューラと同一 config ファイルを共有しない

---

## 関連ドキュメント

- [ADR 0033](../../decisions/0033-snippet-scheduler-separation.md) — スニペットとスケジューラを分離した設計判断
- [scheduler.md](./scheduler.md) — スケジューラ (スニペットとの詳細比較)
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/config/` の配置
