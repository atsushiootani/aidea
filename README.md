# Aidea

> **AI + IDE + Idea** — 個人用の macOS ネイティブ AI 連携ワークスペース

Claude Code をはじめとする AI エージェント連携、本物の WebKit ブラウザ、ターミナル、`~/.claude/` 配下のリソース閲覧を 1 つの macOS アプリに統合する。コードエディタは含まず、既存のエディタ (JetBrains / Neovim 等) と並行して使う。

| | |
|---|---|
| **言語/フレームワーク** | Swift 5.9+ / SwiftUI / WebKit / SwiftTerm |
| **対象** | macOS 15 (Sequoia) 以上 |
| **配布** | 個人用 (Personal Team 署名のみ) |
| **状態** | MVP 実装中 |

## クイックスタート

```bash
git clone https://github.com/atsushiootani/aidea.git
cd aidea
open Aidea/Aidea.xcodeproj
```

Xcode で `⌘R`。ビルド・実行手順の詳細は [`Aidea/README.md`](./Aidea/README.md) を参照。

## ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/specs/SPEC.md](./docs/specs/SPEC.md) | 仕様書 (Single Source of Truth) |
| [Aidea/README.md](./Aidea/README.md) | macOS アプリのビルド/起動手順 |
| [docs/vision.md](./docs/vision.md) | なぜ作るか、要件、非要件 |
| [docs/architecture.md](./docs/architecture.md) | 技術スタック、レイヤー構成 |
| [docs/features.md](./docs/features.md) | 実装する機能の詳細 |
| [docs/decisions/](./docs/decisions/README.md) | 設計判断記録 (ADR) |
| [docs/roadmap.md](./docs/roadmap.md) | 実装スケジュール |
| [CLAUDE.md](./CLAUDE.md) | AI エージェント向けのプロジェクト概要 |

## なぜ作るか (要約)

Vibeyard (Electron 製 IDE) の `<webview>` 制約 (位置情報不可、OAuth 壊れる、permission API 拒否) に耐えられず、**「本来のブラウザの挙動と差異なく開発できることが最優先」** という原則を満たす自作環境を週末プロジェクトとして育てる。詳細は [docs/vision.md](./docs/vision.md)。

## ライセンス

個人用プロジェクトのため未定。

---

*このリポジトリは元々 [agent-skills](https://github.com/obra/superpowers) から派生したため、旧 README は [README.agent-skills.md](./README.agent-skills.md) として保存している。*
