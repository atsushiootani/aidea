# Aidea (macOS App)

> AI + IDE + Idea — 個人用の macOS ネイティブ AI 連携ワークスペース

仕様は [`../docs/SPEC.md`](../docs/SPEC.md)、設計判断は [`../docs/decisions/`](../docs/decisions/) を参照。

## 必要環境

- macOS 15 (Sequoia) 以上
- Xcode 16+
- Swift 5.9+

## ビルド & 起動

1. `Aidea.xcodeproj` を Xcode で開く
2. `⌘R` で Run
3. メニュー **ファイル → ディレクトリを開く...** (`⌘O`) でプロジェクトルートを選択

初回起動時に SwiftPM が SwiftTerm を解決するのを待つ。
projectRoot は `UserDefaults` に保存され、次回以降は自動復元される。

## 重要な設定

### App Sandbox は無効

`~/.claude/` の読み取り、任意ディレクトリへのアクセス、`Process` (PTY) 起動のために
App Sandbox は無効化している。`Signing & Capabilities` で App Sandbox capability を
追加しないこと。

### 署名

Xcode の Personal Team で署名すれば OK。Apple Developer Program ($99/年) は不要。

## 構造

```
Aidea/Aidea/
├─ App/         @main エントリ + メニュー定義
├─ Views/       SwiftUI ビュー
│  ├─ Sidebar/  ファイラ / Skills / Commands / MCPs
│  ├─ Main/     ターミナル
│  └─ RightPanel/ WebView + ファイルプレビュー
├─ Services/    WorkspaceState / Loader / FileWatcher など
├─ Models/      Skill / Command / FileTreeNode など
└─ Utilities/   FrontmatterParser など
```

## 動作確認チェックリスト

- [ ] アプリ起動 → 4 ペインが表示される (左上=ファイラ / 左下=Skills等 / 中=ターミナル / 右=Web/Preview)
- [ ] メニュー「ディレクトリを開く」(⌘O) で aidea プロジェクトを選択できる
- [ ] ファイラに aidea のディレクトリツリーが表示される (`.git` 等は除外)
- [ ] フォルダ展開・折りたたみが NSOutlineView の流儀で動く
- [ ] ターミナルが選んだディレクトリで開く ※ `claude` は手動で打つ ([ADR 0008](../docs/decisions/0008-no-claude-autostart.md))
- [ ] サイドバー Skills/Commands に `~/.claude/` と `<project>/.claude/` の内容が並ぶ (USER/PROJECT バッジ付き)
- [ ] サイドバーの折りたたみグループが `▶` で開閉する
- [ ] ファイル選択で右ペインが Preview に切り替わり中身が表示される
- [ ] 外部で `touch newfile.txt` するとファイラに自動で出現する (FSEvents)
- [ ] 右ペインの Web/Preview Picker で手動切替できる
- [ ] アプリを再起動すると前回の projectRoot が復元される

## 既知の制約 (MVP 範囲外)

- ファイラの編集系操作 (作成・リネーム・削除・D&D) は未実装
- Git ビュー / AI チャット / Obsidian 連携は未実装
- 1 ウィンドウ = 1 プロジェクト固定 (複数同時オープン不可)
- 詳細は [`../docs/SPEC.md`](../docs/SPEC.md) の「MVP に含まないもの」セクション
