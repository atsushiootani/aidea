# Design Decisions

設計上の判断を記録する。あとから「なぜこうしたんだっけ？」となった時のため。

## D1: Electron ではなく Swift/SwiftUI を採用

**日付**: 2026-04-08
**状態**: 採用

### 背景
Vibeyard（Electron 製）を試用したが、`<webview>` タグの制約で位置情報・OAuth・permission API 等が壊れる問題を確認。

### 検討した代替案
- Electron + TypeScript + React
- Tauri + Rust + React
- Swift + SwiftUI
- Flutter Desktop
- Zed 方式（Rust + GPU）

### 判断
**Swift + SwiftUI + WKWebView** を採用。

### 理由
1. WKWebView は **Safari と同じ WebKit エンジン**で、Geolocation や OAuth が OS の権限システムで自然に動く
2. macOS 専用と割り切ることで、クロスプラットフォームの妥協が不要
3. `Process` / `URLSession` / `FileManager` で外部連携が自然
4. 長期メンテ時、Apple の公式フレームワークの方が安定

### トレードオフ
- Chrome 固有機能（Web Bluetooth 等）は WKWebView で動かない → 別途 Chrome を併用
- Electron に比べ UI 開発のホットリロードは弱い → Xcode Previews で代替
- Rust / Tauri よりエコシステムは狭い領域あり（ただし macOS only なら Apple 側が手厚い）

---

## D2: コードエディタ機能を持たない

**日付**: 2026-04-08
**状態**: 採用

### 背景
JetBrains 系 IDE を現在使用しているが、将来的に離脱予定。一方で Aidea にフルスペックのエディタを実装するのは過大な労力。

### 判断
Aidea は **コードエディタを持たない**。エディタは別プロセス（JetBrains、Neovim、その他）に任せる。

### 理由
1. エディタ実装は LSP、シンタックスハイライト、折りたたみ、補完等で数百時間レベル
2. 既存のエディタで十分高機能
3. Aidea の目的は「AI エージェント連携の統合環境」であり「エディタを持つこと」ではない

### トレードオフ
- エディタとの連携は別途必要（ファイル選択時に外部エディタで開く等）
- エディタ内でしか取れない情報（カーソル位置等）は取れない

---

## D3: Claude API を直接叩く（Claude Code CLI は別途使う）

**日付**: 2026-04-08
**状態**: 採用

### 背景
Claude と対話する手段は 2 つある：
1. Claude Code CLI をターミナルで動かす
2. API を直接叩いてチャット UI を作る

### 判断
**両方採用**。メインの対話は CLI（ターミナル内）、補助的なクイック質問は API 直叩きチャットペイン。

### 理由
- Claude Code CLI は既に高機能で、エージェント機能・ツール呼び出し・コンテキスト管理が揃っている
- それを自作で再実装するのは無意味
- 一方で「チャット的にサクッと質問」したいケースもある（Git diff の解説を求めるとか）
- そのときに CLI を起動するのは大げさ

### トレードオフ
- チャットペインでは Claude Code のエージェント機能は使えない（ツール呼び出しなど）
- ユーザーが使い分ける必要がある

---

## D4: Git diff は WebView + diff2html で表示

**日付**: 2026-04-08
**状態**: 暫定

### 背景
`git diff` の出力を見やすく表示する必要がある。

### 検討案
- SwiftUI でネイティブ描画
- NSTextView で属性付き文字列
- WebView に HTML を流し込む

### 判断
**WebView + [diff2html](https://diff2html.xyz/)** を採用（暫定）。

### 理由
1. 既に WKWebView がアプリに含まれている
2. diff2html は枯れた JS ライブラリで見た目が最強
3. シンタックスハイライトも diff2html が担当
4. 自作で描画するより圧倒的に楽

### 見直し条件
- パフォーマンス問題が出たら（大きな diff で重い）
- よりネイティブ感を出したくなったら

---

## D5: Obsidian 連携は URL スキーム + 直接ファイル操作のハイブリッド

**日付**: 2026-04-08
**状態**: 採用

### 検討案
1. URL スキーム（`obsidian://`）のみ
2. Vault のファイルを直接読み書き
3. Local REST API プラグイン使用

### 判断
**1 + 2 のハイブリッド**。

### 理由
- 新規作成・更新はファイル直書きが最速
- 「編集するために Obsidian で開く」は URL スキーム
- Local REST API は追加プラグイン依存で過剰、将来必要になったら追加検討

### トレードオフ
- Vault パスを手動設定する必要がある
- Obsidian 側のリンクグラフが外部更新でリビルドされる（問題ないはず）

---

## D6: 外部依存は SwiftTerm のみに絞る

**日付**: 2026-04-08
**状態**: 採用

### 判断
外部依存は SwiftTerm 1 つのみ。それ以外は Apple 標準フレームワーク（Foundation, SwiftUI, AppKit, WebKit, Security）で賄う。

### 理由
- 個人プロジェクトで依存が増えると破綻しやすい
- Apple 標準は長期メンテされる保証がある
- サードパーティ依存はアップデートが止まると詰む

### 採用ライブラリ
- **SwiftTerm** (MIT): ターミナル UI。自作は現実的でない

### 採用を見送ったもの
- SwiftGit2 → `git` コマンド直叩きで十分
- Alamofire → `URLSession` で十分
- MarkdownUI → SwiftUI 標準の `Text` + `AttributedString` で様子見

---

## D7: 名前は Aidea

**日付**: 2026-04-08
**状態**: 確定

### 候補
- Aide, Aidea, Aigen, Ideai, Agide
- Aibou, Daiku, Aikido
- Forge, Anvil, Loom, Atelier
- Axon, Aiden, Aegis

### 判断
**Aidea**

### 理由
- **AI + IDE + Idea** のトリプルミーニング
- 発音しやすい（アイディア）
- `aidea` コマンドとしてもキレイ
- ドメイン / bundle ID 取得可能（`com.aidea.app`）

### 不採用理由（他候補）
- Aide: 短すぎてググラビリティ低
- Aibou: 英語圏に伝わらない
- Forge/Anvil: AI 要素が名前に無い

---

## D8: ターミナルでは claude を自動起動しない（対話シェルで起動する）

**日付**: 2026-04-08
**状態**: 採用

### 背景
TerminalView 起動時に「プロジェクトルートに cd → そのまま `claude` を実行」を狙って、
最初は以下の実装にしていた：

```swift
// NG パターン
terminal.startProcess(
    executable: "/bin/zsh",
    args: ["-l", "-c", "cd /path && exec claude"],
    environment: env
)
```

これで起動すると `claude` が以下のエラーを返すようになった：

```
API Error: 400 {"type":"error","error":{"type":"invalid_request_error",
"message":"Third-party apps now draw from your extra usage, not your plan
limits. We've added a $100 credit to get you started..."}}
```

### 原因
- 認証は **Claude Max Account** で正しい (`ANTHROPIC_API_KEY` も未設定)
- にもかかわらず Anthropic 側が「サードパーティアプリ扱い」と判定していた
- 検証の結果、`zsh -l -c "..."` で **非対話シェル** から `claude` を exec すると判定が発動
- ターミナル内で **手動で `claude` を打つ場合は問題なし**
- `TERM_PROGRAM` 環境変数も空だったため、シェルの対話性 / TERM_PROGRAM のいずれか
  (もしくは両方) を Anthropic 側が見ていると推測される

### 判断
**TerminalView は対話シェルだけ起動する**。`claude` の自動実行はしない。

```swift
// OK パターン
let command = "cd \(projectRoot) && exec zsh -l"
terminal.startProcess(
    executable: "/bin/zsh",
    args: ["-c", command],
    environment: env
)
```

ユーザーは起動後にターミナル内で手動で `claude` を打つ。

### 理由
1. プラン課金 (Claude Max) のまま使えるのが最優先
2. 「自動で claude が立ち上がる」便利さよりも、本来の枠で動くことの方が重要
3. 対話シェルから手動起動するルートは確実に問題が出ない実証済みの方法

### トレードオフ
- 起動のたびに `claude` を手で打つ手間がある
- → 将来的には「ボタン or キーバインドで claude を起動する」UI で補う余地あり

### 関連メモ
- `TERM_PROGRAM` を `Apple_Terminal` 等に偽装すれば自動起動でも回避できる可能性はあるが、
  Anthropic の利用規約上のグレーゾーンに踏み込むため不採用
- この問題は **Aidea から起動した場合のみ** 発生する。Terminal.app / iTerm2 から
  普通に `claude` を実行する分には問題なし
