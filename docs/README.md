# Aidea

> AI + IDE + Idea — 個人用の Mac ネイティブ AI コーディング環境

## これは何

JetBrains 系 IDE や Vibeyard のような統合ツールから離れて、**macOS ネイティブで自分専用の AI 連携ワークスペース**を作るプロジェクト。

Claude Code をはじめとする AI エージェントとの連携、本物の WebKit ブラウザ、ターミナル、Git、Obsidian 連携を1つのアプリに統合する。コードエディタは含めず、既存のエディタ（当面は JetBrains、将来は未定）と並行して使う想定。

## ドキュメント一覧

| ファイル | 内容 |
|---|---|
| [vision.md](./vision.md) | なぜ作るか、要件、非要件 |
| [architecture.md](./architecture.md) | 技術スタック、レイヤー構成 |
| [features.md](./features.md) | 実装する機能の詳細 |
| [webview-notes.md](./webview-notes.md) | WKWebView vs Safari vs Chrome の比較 |
| [roadmap.md](./roadmap.md) | 実装スケジュール |
| [decisions/](./decisions/README.md) | 設計判断の記録 (ADR) |

## プロジェクト名の由来

**Aidea** = AI + IDE + Idea のトリプルミーニング
- **AI**: AI エージェント連携が中核
- **IDE**: 統合開発「環境」（エディタは含まない）
- **Idea**: アイデアを形にする場所

## 現在の状態

初期セットアップ中。Xcode プロジェクト作成前。
