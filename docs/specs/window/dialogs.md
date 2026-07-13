---
title: ダイアログ
description: Window 共通のモーダルダイアログ (NSAlert / 独自モーダル) のキー割当・破壊操作確認・リアルタイムバリデーション規約
derived_from: []
syncs_with: []
impacts:
  - docs/specs/tools/filer.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# ダイアログ

Window 全体で共通のモーダルダイアログ振る舞い仕様。
`NSAlert` でも独自モーダルでもこのルールに従う。

## キー割当

- **Cancel ボタンは Esc キーで発火する**: すべての `NSAlert` / 独自モーダルダイアログで共通。Cancel に相当するボタンに Esc キーを明示的に割り当てる
- **OK ボタンは Enter キーで発火する** (NSAlert は first button に自動割当なので追加作業不要)

## 破壊的操作・バリデーション

- **破壊的操作 (削除・上書き等) は必ず確認ダイアログを挟む**
- **ファイル/ディレクトリ名などの入力時はリアルタイムバリデーション** を行い、エラー時は赤字メッセージ + OK 無効化
