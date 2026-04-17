# Backchannel 仕様

> Aidea と Claude のファイルベース IPC 機構

## 概要

**Backchannel** は、Aidea アプリとターミナル上で動作する Claude インスタンス間の
ファイルベース通信プロトコル。Aidea は Claude の振る舞いを設定ファイルで制御し、
Claude はファイル書き出しで Aidea にフィードバックを返す。

Aidea は `.aidea/` ディレクトリを共有バスとして使用し、FSEvents でファイル変更を
検知して UI に反映する。

---

## 設計原則

1. **ファイルが API** — プロセス間通信はすべてファイル読み書きで行う
2. **機能宣言方式** — コンパニオンの `initialPrompt` で `.aidea/claude/{feature}.md` を参照することで、Claude 側の Backchannel 機能を有効化する
3. **ターミナル非依存** — ターミナル出力のパースに依存せず、Claude が明示的にファイルを書く
4. **複数ターミナル対応** — 各ターミナルセッションが固有の ID で隔離されたディレクトリを持つ

---

## ディレクトリ構造

```
.aidea/
├── claude/
│   ├── aidea.md              # Aidea 環境の共通指示 (コンパニオン起動時に読み込ませる土台)
│   ├── speech.md             # 読み上げ機能の定義
│   └── {feature}.md          # 将来の機能ごとに 1 ファイル
├── backchannels/
│   ├── speech-{timestamp}.txt  # VOICEVOX 読み上げ用テキスト
│   ├── notify-{timestamp}.txt  # 通知バナー用テキスト (将来)
│   └── ...                     # 将来の Backchannel メッセージ
└── workspace.json              # 既存: レイアウト永続化
```

### パス規約

- `{id}`: ターミナルセッションの一意識別子（UUID またはインスタンス番号）
- `{timestamp}`: ISO 8601 コンパクト形式 (`20260413T153000`)
- `{feature}`: Backchannel 機能名 (例: `speech`)

---

## 機能宣言チェーン

Aidea は Claude セッション起動時に、紐付けられたコンパニオンの `initialPrompt` **のみ**を Claude に送信する。
共通プロンプトのハードコードや `CLAUDE.md` への自動追記は行わない。

コンパニオン側は、`initialPrompt` 内で `.aidea/claude/{feature}.md` を読み込ませることで任意の
Backchannel 機能を有効化する。

### initialPrompt の例

デフォルト (Aidea 環境の土台 + 読み上げ):

```
.aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね
```

読み上げのみ有効にする場合:

```
.aidea/claude/speech.md を読んで読み上げを有効にしてね
```

複数機能を有効にする場合は、参照行を複数書く。
`initialPrompt` が空のコンパニオンは Backchannel 機能を一切持たず、送信メッセージも発生しない。

### 機能ファイルの構成

各 Backchannel 機能は `.aidea/claude/{feature}.md` として独立した 1 ファイルを持ち、
ファイル内容は該当機能の単独の指示書として完結している。
Aidea は初回セットアップ時 (`.aidea/claude/` ディレクトリが存在しないとき) のみ、
Bundle 内の既知の機能ファイルを `.aidea/claude/` にコピーする。既存ファイルは上書きしない
(ユーザ編集の保護)。

---

## ファイル監視

Aidea は `.aidea/backchannels/` ディレクトリを FSEvents で監視する。
ファイルパターンに応じて対応するハンドラにディスパッチする。

| ファイルパターン | ハンドラ | 参照仕様 |
|-----------------|---------|---------|
| `speech-*.txt` | SpeechWatcher → VoicevoxService | [voicevox.md](./voicevox.md) |

---

## メッセージ種別（現在 + 将来）

| 種別 | ファイルパターン | 形式 | 用途 |
|------|-----------------|------|------|
| **Speech** | `speech-{timestamp}.txt` | プレーンテキスト | VOICEVOX 読み上げ |
| Notification | `notify-{timestamp}.txt` | プレーンテキスト | 通知バナー表示 |
| Action | `action-{timestamp}.json` | JSON | UI 操作の指示 |
| Status | `status.json` | JSON | Claude の作業状態表示 |

**太字**は実装済み / 実装予定。それ以外は将来の拡張ポイント。

---

## 境界

### Always
- `.aidea/` 配下のファイル監視は FSEvents を使う
- 処理済みファイルは削除してクリーンアップする
- 全ターミナルから `.aidea/backchannels/` に書き出す
- `.aidea/claude/{feature}.md` は初回セットアップ時に Bundle からコピーする
- Claude セッション起動時に送信するのはコンパニオンの `initialPrompt` のみ

### Never
- ターミナル出力の直接パースに依存しない
- Claude のプロンプトパターンマッチに依存しない
- `.aidea/claude/{feature}.md` の既存ファイルを上書きしない (ユーザ編集を保護)
- Aidea 側から共通プロンプトをハードコードで送信しない
- `CLAUDE.md` を Aidea が自動改変しない
