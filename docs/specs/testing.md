# Testing Strategy

## 基本方針

個人用プロジェクトのため、**テストは最小限**。手動動作確認を優先し、まず動くものを作る。
自動テストは「壊れると気づきにくい部分」に絞って書く。

## 自動テスト対象 (XCTest)

- `FrontmatterParser` (純粋関数、入出力が明確)
- `SkillsLoader` / `CommandsLoader` / `McpLoader` のパース部分 (将来追加)

フレームワーク: **XCTest** (Apple 標準)。外部依存は追加しない。

## 手動動作確認チェックリスト

アプリリリース前 (自分で使う前) に通すチェック:

### 起動 / ワークスペース
- [ ] アプリ起動 → 4 ペインが表示される (左上=ファイラ / 左下=Skills等 / 中=ターミナル / 右=Web)
- [ ] メニュー「ディレクトリを開く」(⌘O) で Aidea プロジェクトを開ける
- [ ] 再起動で前回の projectRoot が自動復元される

### Tab / Session
- [ ] 各ペインの `+` ボタンから新しい Session を追加できる
- [ ] Filer は 1 つ既に存在するとき `+` メニューに出ない (シングルトン)
- [ ] Tab の `×` でクローズできる
- [ ] Tab クリックでアクティブ化できる
- [ ] SwiftUI 系セッション (Skills/Commands/MCPs/Preview) は本体クリックでもアクティブ化できる
- [ ] 青いアクティブハイライトは Window 全体で常に 1 つだけ
- [ ] 非アクティブペインの選択中タブは薄いグレーで区別される

### 各 Tool
- [ ] Terminal で `claude` を手動起動できる (自動起動はしない、ADR 0008)
- [ ] Terminal が他タブに隠れて再表示されても内容が保持される
- [ ] Web に apple.com が表示される
- [ ] Web は他タブに隠れても URL が維持される
- [ ] Filer に `~/.claude/` と `<project>/.claude/` の内容が表示される (`.git` 等は除外)
- [ ] フォルダ展開・折りたたみが NSOutlineView の流儀で動く
- [ ] 外部で `touch newfile.txt` するとファイラに自動で出現する (FSEvents)
- [ ] Skills/Commands に USER/PROJECT バッジが表示され、グループが `▶` で開閉する
- [ ] Filer のファイルをダブルクリックすると、非 Filer ペインに Preview Session が作成される
- [ ] 同じファイルを再度ダブルクリックすると既存の Preview Tab がアクティブ化される
- [ ] Preview タブ名が表示中ファイル名になる
- [ ] Preview でテキスト・画像が表示される
- [ ] 1MB 超やバイナリは非対応メッセージが出る

## 将来のテスト拡張 (MVP 後)

- UI スナップショットテスト
- Service レイヤの統合テスト (実ファイルシステムを使ったフィクスチャ)
- Session のペイン移動での状態保持テスト
