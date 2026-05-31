---
title: Aidea を使い始める (Getting Started)
description: 初回ユーザー向けの導入ガイド。ビルド/署名/起動/ディレクトリ選択/VOICEVOX 導入/ターミナルで claude 起動/Companion の起動・名前/アイコン/指示書編集までを通しで実施するための手順
derived_from:
  - docs/decisions/0008-no-claude-autostart.md
  - docs/specs/backchannels/voicevox.md
  - docs/specs/companions/companion.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-31
---

# Aidea を使い始める (Getting Started)

Aidea を初めて手元で動かし、Claude セッションを開始するまでの一通りの手順。
詳細仕様は [docs/specs/](../specs/README.md) を、なぜこの設計かは [docs/foundation/vision.md](../foundation/vision.md) を参照。

## 必要環境

- macOS 15 (Sequoia) 以上
- Xcode 16 以上
- Swift 5.9 以上
- Apple ID (Personal Team 署名で動かすため。Apple Developer Program は不要)
- **VOICEVOX** (任意 — Companion の音声読み上げを使うなら必須。後述「6. VOICEVOX を導入する」参照)

## 1. リポジトリを取得

```bash
git clone https://github.com/atsushiootani/aidea.git
cd aidea
```

## 2. Xcode で開く

```bash
open Aidea/Aidea.xcodeproj
```

初回起動時、Xcode が SwiftPM 経由で SwiftTerm を解決する。完了するまで待つ。

## 3. 署名を設定する (初回のみ)

Xcode で `Aidea` ターゲットを選択 → `Signing & Capabilities` タブ:

- **Team**: 自分の Apple ID (Personal Team) を選ぶ
- **App Sandbox**: capability を**追加しない**

App Sandbox を無効のまま運用するのは `~/.claude/` の読み取りと任意ディレクトリへの
アクセス、`Process` (PTY) 起動のために必要。Sandbox を有効化すると主要機能が動かなくなる。

## 4. アプリをビルド & 起動

`⌘R`。ウィンドウが立ち上がり、4 ペインが表示される。

| ペイン | 内容 |
|---|---|
| 左上 | ファイラ (プロジェクトのディレクトリツリー) |
| 左下 | Skills / Commands / MCPs (`~/.claude/` と `<project>/.claude/` を統合表示) |
| 中央 | ターミナル |
| 右 | Web ブラウザ / ファイルプレビュー |

## 5. 作業対象のプロジェクトを開く

メニュー **ファイル → ディレクトリを開く...** (`⌘O`) で対象プロジェクトのルートを選択する。
選んだパスは `UserDefaults` に保存され、次回以降は自動復元される。

## 6. VOICEVOX を導入する (任意 / 読み上げを使うなら必須)

Aidea の Companion は `.aidea/backchannels/<N>/speech-*.txt` を書き出し、
それを **ローカルで動く VOICEVOX エンジン** (`http://localhost:50021`) に投げて
音声合成 → 再生する構成になっている。Aidea 側に VOICEVOX エンジンは同梱されないので、
読み上げを使うなら**自分で導入・起動**する必要がある。
詳細仕様は [docs/specs/backchannels/voicevox.md](../specs/backchannels/voicevox.md) を参照。

### 導入手順

1. [VOICEVOX 公式サイト](https://voicevox.hiroshiba.jp/) から macOS 版をダウンロード
   - Apple Silicon / Intel どちらも公式が用意している
2. `.dmg` を開き、`VOICEVOX.app` を `Applications` にコピー
3. `VOICEVOX.app` を起動する
   - 初回起動時に音声モデルのダウンロードが走る場合がある
   - 起動が完了すると裏で REST API サーバが `http://localhost:50021` で待機する
4. ブラウザで `http://localhost:50021/version` を開いてバージョン番号が返れば疎通 OK

### Aidea 側の確認

Aidea を起動した状態で:

- ヘッダの **「VOICEVOX が起動していません」表示が消える** → 接続成功
- 任意の Companion を起動して数文字プロンプトを送ると、`.aidea/backchannels/<index>/speech-*.txt`
  が書き出され、自動で読み上げが走る
- ヘッダの スピーカーアイコン (`speaker.wave.2.fill`) クリック or **`⌥⌘M`** で読み上げ ON/OFF をトグル

### スピーカーの選び方

- デフォルトは **スピーカー ID `20` (もち子さん)**
- Companion ごとに固定したいときは、Companion の `instructions.md` で
  「ID:N (キャラ名) で読み上げてね」と指示する (例: 四国めたんノーマル = `2`)
- ID の一覧は VOICEVOX の `GET /speakers` でも取得できる

### 読み上げを使わない場合

VOICEVOX を導入しなくても Aidea 本体は動作する。ヘッダに警告が出るだけで、
ターミナル / ファイラ / プレビュー / Skills など他機能は通常通り使える。
読み上げを永続的に使わない場合は、ヘッダのスピーカーアイコンで OFF にしておけば警告も静かになる。

## 7. ターミナルで claude を手動起動する

中央ペインのターミナルで:

```bash
claude
```

> **Aidea は `claude` を自動起動しない**。
> Anthropic が非対話シェルからの `claude` 実行を「サードパーティアプリ」と
> 判定して Claude Max プランの枠で動かせなくなるため、対話シェル内で手動起動する。
> 詳細は [ADR 0008](../decisions/0008-no-claude-autostart.md) を参照。

`claude` コマンドが見つからない場合は、`which claude` が通る環境にインストール
されているか、PATH が引き継がれているかを確認する。

## 8. Companion を起動・設定する

ヘッダ上部に並ぶ 9 体のアイコンが **Companion** (1 体 = 1 Claude セッション)。
index 0〜8 で固定され、増減できない。デフォルト名は index 順に
`main-chan` / `doc-chan` / `review-chan` / `red-chan` / `yellow-chan` / `idea-chan` / `concier-chan` / `black-chan` / `quick-chan`。

### 8-1. クリック操作の早見表

ヘッダ Companion 上では「アイコン」と「名前ラベル」でクリックの意味が違う。

| クリックする場所 | 動作 |
|---|---|
| **アイコン (画像)** が未起動 (グレーアウト状態) | その Companion で Claude セッションを起動して bind |
| **アイコン (画像)** が起動済み | 紐付く Claude セッションを前面にアクティブ化 |
| **名前ラベル** (アイコン下の文字) | `CompanionEditView` の編集シートを開く |

### 8-2. 名前・アイコンを変える

名前ラベル (例: `main-chan`) をクリックすると、編集シートが開く。

- **名前**: テキスト入力で変更。変更すると即座にヘッダのラベル・タブ表示と
  `.aidea/claude/aidea.md` 内のコンパニオン名簿 ([companion-roster](../specs/backchannels/companion-roster.md))
  にも反映される (= Companion 同士のハンドオフ宛先名としても使われる)
- **アイコン**: 9 枚のプリセット (`companion-1` 〜 `companion-9`) から選択
- **指示書を開く**: ボタンを押すと `.aidea/claude/companions/<index>/instructions.md`
  が右ペインの Preview として開き、markdown 編集モードに入れる

`OK` で保存すると `workspace.json` (v8) に永続化され、次回起動時にも復元される。

### 8-3. 指示書 (`instructions.md`) で個別カスタマイズ

各 Companion の **役割・性格・読み上げのキャラ・起動時のあいさつ** はテキストファイルで決まる。
場所は:

```
.aidea/claude/companions/<index>/instructions.md
```

初回 Companion 起動時 (もしくは `BackchannelSetup` 走行時) に Bundle 同梱の
テンプレートが 9 個に複製される (既存ファイルは上書きしない)。

典型的なテンプレート:

```markdown
.aidea/claude/aidea.md の指示に従ってね
.aidea/claude/speech.md の指示に従い、ID:2(四国めたんノーマル)で読み上げてね

元気よく、Z世代女子のように喋って
プロンプトの読み上げ文面は "メインちゃん スタンバイです！" にして

## このコンパニオンの役割

(ここに固有の役割や知識を書く)
```

書き換えポイント:

| 行 | 役割 |
|---|---|
| `aidea.md` 参照行 | Backchannel の起動規約を読み込ませる (= ハンドオフ等) |
| `speech.md` 参照行 + `ID:N(キャラ名)で読み上げて` | この Companion の VOICEVOX スピーカー固定 (削除すると読み上げ無効) |
| 口調指示行 (例: `元気よく Z世代女子のように喋って`) | キャラの口調を決める |
| `プロンプトの読み上げ文面は "〜" にして` | 起動時の最初の speech を固定文面にする (要点要約ではなくこの文面が読み上げられる) |
| `## このコンパニオンの役割` 以降 | 役割固有の指示 (例: doc-chan ならドキュメント整備担当、review-chan ならコードレビュー専任 など) |

Companion を起動すると Aidea が自動で以下のプロンプトを最初に送る:

```
.aidea/claude/companions/<index>/instructions.md を読んで従ってね
```

これにより Claude が `instructions.md` を読み込み、上記の指示に従い始める。

### 8-4. (発展) キャラ本体を `.claude/agents/` に切り出す

`instructions.md` を肥大化させずに、口調・担当範囲・tools 制約など**キャラ本体の定義**を Claude Code 標準の subagent ファイル (`.claude/agents/<name>.md`) に切り出すと、Aidea を使わない (素の Claude Code で起動する) ときも同じキャラ運用ができる。

#### 設計の振り分け

| 置き場所 | 内容 | 理由 |
|---|---|---|
| `.claude/agents/<name>.md` | 口調 / 担当範囲 / 役割 / `tools` / `model` などキャラ本体 | Claude Code 標準。`claude --agent <name>` 起動でも `Agent({subagent_type: "<name>"})` 呼び出しでも同じ定義が読まれる |
| `.aidea/claude/companions/<index>/instructions.md` | Aidea 起点情報のみ (`aidea.md` 参照 / `speech.md` 参照 + VOICEVOX speaker ID / 起動文面 / 上記 agents への段階的参照) | Aidea ハーネス固有 (PTY 起動時に Aidea がこのファイルだけを最初に流し込む) |

#### `.claude/agents/<name>.md` の形式

Claude Code 標準の YAML frontmatter を使う:

```markdown
---
name: doc-chan
description: ドキュメント作成・整理・編集を担当する気品あるキャラ。仕様書 / 設計書 / メモ / README / ブログ記事 など文章全般。
---

# doc-chan

ドキュメント担当。

## 口調

気品のある喋り方。落ち着いたトーンで丁寧に。

## 担当範囲

- 仕様書・設計書・ADR の作成・編集
- README やオンボーディング文書
- ブログ記事 / Notion 記事の下書き・推敲
```

- `name` は Companion 名と一致させる (Aidea の `aidea.md` 内 companions ロスタとも揃える)
- `description` は「いつこのキャラに任せるか」を 1-2 文で。サブエージェントとして自動委譲の判断材料にも使われる
- `tools` / `model` / `permissionMode` フィールドで権限・モデル・ツール制約も指定可能 (省略時は親継承)

#### `instructions.md` 側の段階的参照

キャラ本体を agents 側に置いたら、`instructions.md` は薄く保ち、段階的開示として agents への参照を入れる:

```markdown
.aidea/claude/aidea.md の指示に従ってね
.aidea/claude/speech.md の指示に従い、ID:107(東北ずん子)で読み上げてね
.claude/agents/doc-chan.md を読んで、キャラ設定 (口調・担当範囲) に従ってね

最初のプロンプトの読み上げ文面は "ドックちゃん スタンバイです！" にして
```

これで Aidea 経由で起動しても agents の内容が読まれ、Aidea を使わずに `claude --agent doc-chan` や Agent tool で呼んでも同じキャラとして振る舞う。

#### 共有とローカル所有の境界

[CLAUDE.md トップレベル構成](../../CLAUDE.md) のとおり `.claude/` は**ローカル個人のスキル/コマンド** (gitignore 対象、共有しない)。チームで使い回す場合は、各メンバーが自分の `.claude/agents/<name>.md` を整備する運用にする (本節を参考に各自セットアップ)。

### 8-5. アイコンの状態表示

起動後のアイコンは状態に応じて表情とオーバーレイが変わる ([詳細](../specs/companions/companion.md#表情状態表示-issue-45))。

| 状態 | ベース画像 | バッジ |
|---|---|---|
| 未起動 | グレーアウト (彩度 0.3 / 不透明度 0.5) | なし |
| アイドル | 通常表情 | なし |
| 実行中 (Claude が処理中) | 考え中の表情 | `ellipsis.bubble` |
| 読み上げ中 (VOICEVOX 再生中) | 笑顔 | `heart.fill` (pink) |

詳細仕様は [docs/specs/companions/companion.md](../specs/companions/companion.md) を参照。

## 9. Skills / Commands を眺める

左下ペインで Skills / Commands タブを切り替えると、

- `~/.claude/` (USER バッジ) — グローバル
- `<project>/.claude/` (PROJECT バッジ) — このプロジェクト固有

の両方が並んで表示される。スキル / スラッシュコマンドの追加はこのディレクトリに
ファイルを置くだけで反映される (FSEvents で自動検出)。

## キーボードショートカット

全キーボードショートカットとマウス操作は [docs/specs/aspects/keybindings.md](../specs/aspects/keybindings.md) に機能群横断で集約してある。

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| ビルドが「Cannot find ... in scope」で失敗する | SwiftPM の解決待ち。`File → Packages → Resolve Package Versions` を再実行 |
| 起動時に Sandbox エラーが出る | `Signing & Capabilities` で App Sandbox capability が追加されていないか確認し、追加されていれば削除 |
| ターミナルで `Third-party apps now draw from your extra usage...` | [ADR 0008](../decisions/0008-no-claude-autostart.md) 参照。`exec claude` 形式での自動起動になっていないか確認 |
| `claude` コマンドが見つからない | ターミナル内で `which claude` を実行。PATH が引き継がれていなければ `~/.zshrc` を確認 |
| ファイラに `.git` や `node_modules` が出てくる | 既定で除外対象。出るのは不具合。Issue を立てる |
| ヘッダに「VOICEVOX が起動していません」と出る | `VOICEVOX.app` を起動 → `http://localhost:50021/version` がブラウザで返るか確認。読み上げを使わないなら `⌥⌘M` で OFF |
| `VOICEVOX.app` を起動しても疎通しない | 他アプリが 50021 番ポートを使っていないか `lsof -i :50021` で確認。VOICEVOX の再起動も試す |

## 次に読む

| 知りたいこと | 参照先 |
|---|---|
| プロダクト仕様 (機能の挙動) | [docs/specs/](../specs/README.md) |
| キーボード/マウス操作一覧 | [docs/specs/aspects/keybindings.md](../specs/aspects/keybindings.md) |
| 動機・原則 | [docs/foundation/vision.md](../foundation/vision.md) |
| アーキテクチャ | [docs/specs/architecture.md](../specs/architecture.md) |
| コーディング規約 (開発者向け) | [docs/conventions/](../conventions/README.md) |
| 設計判断記録 (ADR) | [docs/decisions/](../decisions/README.md) |
