# Aidea (macOS App)

> AI + IDE + Idea — 個人用の macOS ネイティブ AI 連携ワークスペース

仕様は [`../SPEC.md`](../SPEC.md)、設計判断は [`../docs/decisions/`](../docs/decisions/) を参照。

## 必要環境

- macOS 15 (Sequoia) 以上
- Xcode 16+
- Swift 5.9+

## ビルド & 起動

1. `Aidea.xcodeproj` を Xcode で開く
2. `⌘R` で Run

初回起動時に SwiftPM が SwiftTerm を解決するのを待つ。

## 重要な設定

### App Sandbox は無効

`~/.claude/` の読み取りや `Process` (PTY) 起動のために App Sandbox は無効化している。
`Signing & Capabilities` で App Sandbox capability を追加しないこと。

### 署名

Xcode の Personal Team で署名すれば OK。Apple Developer Program ($99/年) は不要。

## 構造

```
Aidea/Aidea/
├─ App/         @main エントリ
├─ Views/       SwiftUI ビュー
│  ├─ Sidebar/  Skills/Commands/MCPs 一覧
│  ├─ Main/     ターミナル
│  └─ RightPanel/ WebView
├─ Services/    ファイル走査などの副作用層
├─ Models/      データモデル
└─ Utilities/   FrontmatterParser など
```

## 動作確認チェックリスト

- [ ] アプリ起動 → 3 ペインが表示される
- [ ] ターミナルで `claude` を実行できる (※ 自動起動はせず手動で打つ。理由: [ADR 0008](../docs/decisions/0008-no-claude-autostart.md))
- [ ] WebView に apple.com が表示される
- [ ] サイドバー Skills/Commands に `~/.claude/` と `<project>/.claude/` の内容が並ぶ (USER/PROJECT バッジ付き)
- [ ] サイドバーの折りたたみグループが `▶` で開閉する

## 既知の制約 (MVP 範囲外)

- プロジェクトルートはハードコード (将来: ワークスペース管理機能で切替)
- Git ビュー / AI チャット / Obsidian 連携は未実装 (SPEC.md 将来項目)
