---
title: "0022: コンパニオン初期指示を外部 Markdown ファイルに分離する"
description: コンパニオンの initialPrompt を workspace.json 内文字列から .aidea/claude/companions/<index>/instructions.md に移行する設計
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# 0022: コンパニオン初期指示を外部 Markdown ファイルに分離する

**日付**: 2026-04-23

## 背景

`CompanionConfig.initialPrompt` は v7 までの `workspace.json` に **JSON 文字列として埋め込まれていた** (`companions[].initialPrompt`)。各コンパニオンの初期プロンプトは Claude セッション起動時に PTY 経由で `send()` され、Claude が `.aidea/claude/aidea.md` 等を読み込む起点として機能してきた。

issue #99 で Companion 別レコメンドプロンプトに対応した結果、9 体のコンパニオンを役割別 (例: テスト担当 / レビュー担当 / レビュー結果報告担当) に運用する想定が現実味を帯び、それに伴って **各 Companion が長文の指示書を持つ** 可能性が高くなった。

## 問題

1. **JSON 文字列としての可読性が低い**: 1 KB を超える長文プロンプトを `workspace.json` に押し込むと、git diff も読みづらく、改行・コードブロック・段階的開示 (他ファイル参照) を仕込みにくい。
2. **Aidea ロックイン**: `initialPrompt` は Aidea が解釈する前提で `workspace.json` に格納されている。Aidea を将来使わなくなったとき、ユーザは JSON から手作業で文字列を取り出して `claude` CLI に渡す必要がある。
3. **段階的開示の余地が無い**: 1 個の文字列フィールドでは、起動時の本体指示と「必要に応じて Claude が読みに行く補助ファイル」を構造化できない。

## 決定

`CompanionConfig.initialPrompt` を **削除** し、各コンパニオン固有の指示書を `<projectRoot>/.aidea/claude/companions/<index>/instructions.md` に外部化する。Aidea は起動時に `companionIndex` から派生した固定文字列「`.aidea/claude/companions/<index>/instructions.md` を読んで従ってね」を `send()` するのみで、内容自体は持たない。

```
<projectRoot>/.aidea/claude/
├── aidea.md                       # 共有: Backchannel 機能の指示 (現存)
├── speech.md                      # 共有: 読み上げ機能の指示 (現存)
└── companions/
    ├── 0/
    │   ├── instructions.md        # ← Aidea が起動時に読ませるエントリーポイント
    │   ├── persona.md             # (任意) 段階的開示の参照先 例
    │   └── ...
    ├── 1/instructions.md
    ├── ...
    └── 8/instructions.md
```

- **エントリーポイント**: `instructions.md` (固定)。同ディレクトリ内の他ファイルは `instructions.md` から相対参照する形で段階的開示する
- **共有指示書**: `aidea.md` / `speech.md` は現状通り `.aidea/claude/` 直下に置いたまま。`instructions.md` 冒頭から参照する慣例で再利用する
- **Aidea の責務**: PTY に固定パターン文字列を送るだけ。ファイル本体は読まない
- **マイグレーション**: `workspace.json` v7 → v8 で `companions[].initialPrompt` を削除し、`.aidea/claude/companions/<index>/instructions.md` が不在の場合のみ v7 の文字列を書き出す (既存ファイル尊重 = ユーザ編集保護)
- **Bundle テンプレ**: `Aidea/Resources/Backchannels/companion-instructions.md` を新規追加し、新規プロジェクト起動時に `BackchannelSetup` が 9 個に複製する (既存ファイルは上書きしない、`aidea.md` / `speech.md` と同じ仕組み)
- **編集 UI**: `CompanionEditView` の `initialPrompt` 編集 TextEditor を撤去し、「指示書を開く」ボタンに置き換える。ボタンは `SessionRegistry.openPreview(for:title:)` を経由して Preview セッション (markdown view + 編集モード) で開く
- **配置場所**: `.aidea/` 内のため git 管理外 (個人設定扱い)。ユーザは Aidea を辞めるときに `.aidea/claude/companions/` を手動で持ち出す前提

## 結果

- **可搬性**: Aidea を撤去しても `.aidea/claude/companions/<index>/instructions.md` がそのまま使えるため、`cat … | claude` 等で同じワークフローを再現できる
- **段階的開示**: `instructions.md` から `./persona.md` `./workflow.md` などを必要時に読み込める。1 個の文字列フィールドではできなかった構造化指示が可能に
- **編集体験**: ユーザは Aidea 内 (Preview セッション) でも、外部エディタでも同じファイルを編集できる
- **責務分離**: `workspace.json` はランタイム状態 (sessionID / レイアウト / レコメンド設定) のみを保持。指示書はファイルシステム任せ
- **ハードコード集約**: 起動時の固定パターン文字列とパス組み立ては `CompanionInstructions` enum に閉じ込め、複数の呼び出し元から再利用する
- **マイグレーション安全性**: ハイブリッド方式 (ファイル不在時のみ書き出し) により既存ユーザのカスタマイズ済み指示書を破壊しない

## 不採用案

| 案 | 理由 |
|---|---|
| **`CompanionConfig.initialPromptFile: String?` (パスを workspace.json に保持)** | 結局 `workspace.json` に Aidea 専用フィールドが残るため、ロックイン度合いが中途半端。固定規約 (`companions/<index>/instructions.md`) に揃える方がシンプル |
| **`Aidea` がファイル中身を直接 `send()`** | Claude 側の `Read` トークンは節約できるが、段階的開示 (`./persona.md` を必要時に読む) と相性が悪い。本文中で別ファイル参照を書いても結局 Read を発生させるため利点が打ち消される |
| **共有指示 (`aidea.md` / `speech.md`) を各 companion ディレクトリに分散** | 1 コンパニオン = 1 ディレクトリで完結する利点はあるが、9 ファイル分の重複コストが大きい。共通部分は共有のままで参照する方が DRY |
| **`.aidea/` 外 (例: `<projectRoot>/.claude/companions/`) に配置して git 管理する** | 可搬性は最強だが、コンパニオン編成は個人開発環境固有のため、git に乗せる必然性が薄い。`.aidea/` 配下で個人設定扱いにする方が共同開発時に他者の `.gitignore` を汚さない |
| **`CompanionEditView` 内に編集エディタを内蔵** | UI 機能重複 + Aidea 専用エディタへの依存が増す。Preview セッションを再利用するだけで十分 |

## 関連

- [docs/specs/companions/companion.md](../specs/companions/companion.md) — `CompanionConfig` の最新仕様 (initialPrompt 削除後)
- [docs/specs/sessions/claude.md](../specs/sessions/claude.md) — `companionPrompt` の生成ロジック (`CompanionInstructions.loadCommand(for:)`)
- [docs/specs/aspects/persistence.md](../specs/aspects/persistence.md) — `workspace.json` v8 マイグレーションと Bundle テンプレ
- [docs/specs/backchannels/backchannel.md](../specs/backchannels/backchannel.md) — `BackchannelSetup` のコピー責務
- ADR [0008: ターミナルでは claude を自動起動しない](./0008-no-claude-autostart.md) — 起動時 `send()` の前提
