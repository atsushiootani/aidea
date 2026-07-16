---
title: Session と SessionState
description: Session (全 Tool 共通の薄い入れ物) と SessionState (Tool 固有の内部状態) の関係・役割分担・ライフサイクル呼び出しフロー
derived_from:
  - docs/decisions/0013-session-as-first-class-object.md
  - docs/decisions/0018-session-and-state-separation.md
  - docs/decisions/0020-session-focus-bridge.md
syncs_with:
  - docs/specs/glossary.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/sessions/focus-contract.md
impacts:
  - docs/specs/sessions/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Session と SessionState

Aidea の Session 実体は、**全 Tool 共通の入れ物である `Session`** と **Tool ごとに 1 つ存在する `SessionState`** の 2 階層で構成される。本ファイルは両者の責任分担・関係・ライフサイクル呼び出しフローを集約する。

用語の定義は [glossary.md](../glossary.md)、5 概念モデル全体は [ui-rules.md](./ui-rules.md)、各 Tool ごとの SessionState の詳細は per-tool spec ([filer.md](./filer.md) / [kit.md](./kit.md) / [terminal.md](./terminal.md) / [claude.md](./claude.md) / [web.md](./web.md) / [preview.md](./preview.md) / [git.md](./git.md) / [git-diff.md](./git-diff.md)) を参照。

---

## 関係図

```
┌──────────────────────────────────────────────┐
│  Session (全 Tool 共通の薄い入れ物)              │
│  ──────────────────────────────────────────  │
│  ・識別子 (SessionID)                          │
│  ・SessionState への参照                       │
│                                               │
│  アクティブ化   ── 委譲 ──→ アクティブ化フック    │
│  非アクティブ化 ── 委譲 ──→ 非アクティブ化フック  │
│                                               │
│  ※ AppKit 知識を持たない                       │
│    (ネイティブ View やキー入力の受け手を直接扱わない) │
└──────────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│  SessionState (Tool ごとに 1 実装)              │
│  ──────────────────────────────────────────  │
│  ・Tool 固有のデータと振る舞い                   │
│  ・アクティブ化 / 非アクティブ化のフック          │
└──────────────────────────────────────────────┘
      ▲
      │
  Filer / Terminal / Claude / Web / Preview / Git / GitDiff
   = AppKit 系 (フォーカスブリッジを保持)
  Kit
   = 純 SwiftUI 系 (アクティブフラグのみ)
```

---

## Session クラス

全 Tool で共通の**汎用の入れ物**。Session 実体ごとにインスタンスが作られる。

- **識別子** — Window 内で一意の `SessionID`
- **SessionState への参照** — Tool 固有の状態
- **アクティブ化 / 非アクティブ化** — ライフサイクルイベントの**発火責任者**。中で SessionState のアクティブ化 / 非アクティブ化フックに委譲する
- **AppKit 知識を持たない**: ネイティブ View やキー入力の受け手といった AppKit の仕組みを直接扱わない ([ADR 0020](../../decisions/0020-session-focus-bridge.md))

---

## SessionState プロトコル

Tool ごとに 1 つの具体実装が準拠する**共通インターフェース**。

- Tool 固有のデータと振る舞いを保持する場所
- アクティブ化 / 非アクティブ化のフックを実装する (既定は何もしない)
- 永続化対象 (`workspace.json`) のフィールドはここに置く

### AppKit 系 / 純 SwiftUI 系の区別

各 SessionState は **AppKit 系**または**純 SwiftUI 系**のいずれかとして実装される。区別は持つものの種類で表現する。

| 種別 | 持つもの | フォーカス制御の手段 |
|---|---|---|
| **AppKit 系** | フォーカスブリッジ (専用のブリッジヘルパ) | アクティブ化フックでブリッジを有効化し、非アクティブ化フックで解除する |
| **純 SwiftUI 系** | アクティブフラグ | アクティブ化フックでフラグを立て、非アクティブ化フックで下ろす。SwiftUI のフォーカスバインドがキー入力の受け手の出し入れを自動処理する |

フォーカス契約 (C1 / C2 / C3) は [focus-contract.md](./focus-contract.md) を、その実装規約 (ブリッジヘルパの責務) は [conventions/implementations/focus.md](../../conventions/implementations/focus.md) を参照。

---

## 役割分担

| 観点 | Session (1 種類) | SessionState (8 個の実装) |
|---|---|---|
| **数** | 全 Tool で共通の 1 種類 | Tool ごとに 1 実装 |
| **インスタンス** | 各 Session 実体ごとに 1 つ | Session 1 つに 1 つ紐付く |
| **Tool 固有データ** | 持たない | **持つ** (端末 View / URL / ツリーノード等) |
| **識別子** | 持つ (`SessionID`) | 持たない |
| **AppKit 知識** | **持たない** | AppKit 系のみ持つ (フォーカスブリッジ経由で閉じ込め) |
| **アクティブ化のエントリポイント** | 持つ (SessionRegistry が呼ぶ) | フックを実装 (Session が委譲) |
| **フォーカス契約 (C1/C2/C3)** | 関与しない | フォーカスブリッジ (AppKit 系) またはアクティブフラグ (SwiftUI 系) で履行 |
| **永続化対象** | 識別子のみ | Tool 固有の状態すべて (フォーカスブリッジ / アクティブフラグは非永続) |
| **誰が生成するか** | SessionRegistry のセッション生成処理 | Session 生成時に同時に作る |

---

## Tool ごとの SessionState 実装

Tool ごとの実装の違いは **すべて SessionState 側**にある。各 SessionState の Tool 固有データと振る舞いの概観:

| SessionState | 種別 | Tool 固有のデータ | Tool 固有の振る舞い |
|---|---|---|---|
| **Filer** | AppKit 系 | 選択中ファイル・展開中 URL 集合・除外ルール・ツリー表示コントローラ | ファイルツリー操作 |
| **Terminal** | AppKit 系 | 端末 View (遅延生成) | PTY 起動 |
| **Claude** | AppKit 系 | 端末 View・起動時指示コマンド・Frontchannel 送信 | claude CLI 自動起動 |
| **Web** | AppKit 系 | 現在 URL・WebView・ナビゲーション監視 | URL 永続化、ナビゲーション追従 |
| **Preview** | AppKit 系 / 純 SwiftUI 系 (コンテンツ次第) | URL・タイトル | コンテンツ種別自動判定。ネイティブ View 系コンテンツ (text/drawio) ではフォーカスブリッジを、純 SwiftUI コンテンツ (markdown/image) ではアクティブフラグを使う |
| **Git** | AppKit 系 | モード・ツリーノード・選択パス・ファイル統計・現在ブランチ | git status 取得・パース |
| **GitDiff** | AppKit 系 | モード・diff 出力・確認済みファイル・フォーカス中ファイル | git diff 取得・パース |
| **Kit** | 純 SwiftUI 系 | 4 つのリソースローダ・セクション展開状態・選択・アクティブフラグ | リソース読み込み |

各フィールドの詳細仕様 (ペイン移動での保持・永続化対象等) は per-tool spec ([filer.md](./filer.md) ほか) を SSoT とする。本表は概観のみ。

---

## ライフサイクル呼び出しフロー

```
ユーザーがタブをクリック (or Cmd+[ など)
    │
    ▼
SessionRegistry のアクティブタブ切替
    │
    ├─ 旧 Session を非アクティブ化  ──→  非アクティブ化フック
    │                                     ├─ AppKit 系: フォーカスブリッジを解除
    │                                     │             (キー入力の受け手を解放、契約 C2)
    │                                     └─ SwiftUI 系: アクティブフラグを下ろす
    │                                                   (SwiftUI がフォーカスバインド経由で自動解放)
    │
    └─ 新 Session をアクティブ化    ──→  アクティブ化フック
                                          ├─ AppKit 系: フォーカスブリッジを有効化
                                          │             (キー入力の受け手を自分の配下に、契約 C1)
                                          └─ SwiftUI 系: アクティブフラグを立てる
                                                        (SwiftUI がフォーカスバインド経由で自動取得)
```

**Session が「ライフサイクルイベントの発火」を担当**し、**SessionState が「そのイベントで何をするか」を Tool ごとに実装**する分業構造。Session 自身はフォーカス制御に関与せず、AppKit 知識を持たない。

アクティブ化 / 非アクティブ化を発火させるのは SessionRegistry のアクティブタブ切替の責務。SessionState のフックを直接呼んではならない。アクティブ Session 切替の規約は [active-session.md](./active-session.md) を参照。

---

## 設計の経緯

| 段階 | フォーカス制御の置き場所 | 経路分岐の判断 |
|---|---|---|
| ADR 0012 時代 | 各 SessionState が自前でフォーカス対象 View を管理 | Tool 種別で分岐 |
| ADR 0013 時代 | Session にフォーカス対象 View を集約 | フォーカス対象 View の有無 |
| **現行 (ADR 0020 採用)** | **SessionState のフォーカスブリッジ (AppKit 系) + アクティブフラグ (SwiftUI 系)** | **SessionState がフォーカスブリッジを持つか** |

ADR 0020 で Session からフォーカス対象 View の保持を撤去し、フォーカス契約を SessionState に委譲する形に進化させた。Session を first-class object とする ADR 0013 の核心判断は維持される。詳細は [ADR 0020](../../decisions/0020-session-focus-bridge.md) を参照。

---

## なぜ Session と SessionState を分けるか

`Session` は識別子と SessionState への参照しか持たない薄い入れ物に見えるため、「`SessionState` に識別子を持たせて統合すれば `Session` は不要では」という疑問が起きやすい。技術的には統合可能だが、型システム上の制約・永続化境界・型消去の局所化・ライフサイクル責任の明確化という 4 つの理由で分離を維持している。

→ 詳細な判断と理由は [ADR 0018](../../decisions/0018-session-and-state-separation.md) を参照。

---

## 関連

- [glossary.md](../glossary.md) — Session / SessionState / SessionID / SessionRegistry の用語定義
- [ui-rules.md](./ui-rules.md) — 5 概念モデル (Window / Pane / Tab / Session / Tool)
- [active-session.md](./active-session.md) — アクティブ Session の切替規約
- [focus-contract.md](./focus-contract.md) — キー入力が常にアクティブ Session に届くことを担保する契約 (C1/C2/C3)
- [ADR 0013](../../decisions/0013-session-as-first-class-object.md) — Session を first-class object にする設計判断
- [ADR 0018](../../decisions/0018-session-and-state-separation.md) — Session と SessionState を分離して保持する判断と 4 つの理由
- [ADR 0020](../../decisions/0020-session-focus-bridge.md) — フォーカス契約を SessionState + フォーカスブリッジに委譲する設計
