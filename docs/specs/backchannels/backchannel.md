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
2. **段階的開示** — CLAUDE.md → `.aidea/claude/aidea.md` の参照チェーンで Claude に指示を渡す
3. **ターミナル非依存** — ターミナル出力のパースに依存せず、Claude が明示的にファイルを書く
4. **複数ターミナル対応** — 各ターミナルセッションが固有の ID で隔離されたディレクトリを持つ

---

## ディレクトリ構造

```
.aidea/
├── claude/
│   └── aidea.md              # Aidea が Claude に与える指示書（段階的開示）
├── terminals/
│   ├── speech-{timestamp}.txt  # VOICEVOX 読み上げ用テキスト
│   ├── notify-{timestamp}.txt  # 通知バナー用テキスト (将来)
│   └── ...                     # 将来の Backchannel メッセージ
└── workspace.json              # 既存: レイアウト永続化
```

### パス規約

- `{id}`: ターミナルセッションの一意識別子（UUID またはインスタンス番号）
- `{timestamp}`: ISO 8601 コンパクト形式 (`20260413T153000`)

---

## 段階的開示チェーン

Aidea はプロジェクトの `CLAUDE.md` に以下の参照を**自動で追記**する:

```markdown
@.aidea/claude/aidea.md
```

`.aidea/claude/aidea.md` の内容は Aidea が生成・管理する。Claude はこのファイルを
通じて Backchannel のプロトコルを知る。

### aidea.md の構成

aidea.md は有効な Backchannel 機能に応じてセクションが追加される。
各 Backchannel 機能（Speech 等）が独自のセクションを持つ。

---

## ファイル監視

Aidea は `.aidea/terminals/` ディレクトリを FSEvents で監視する。
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
- 全ターミナルから `.aidea/terminals/` に書き出す
- `.aidea/claude/aidea.md` は Aidea が自動生成・管理する

### Confirm First
- `CLAUDE.md` への `@.aidea/claude/aidea.md` 追記（初回のみ確認）

### Never
- ターミナル出力の直接パースに依存しない
- Claude のプロンプトパターンマッチに依存しない
- `.aidea/claude/aidea.md` をユーザーに手動編集させない
