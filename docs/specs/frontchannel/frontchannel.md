# Frontchannel 仕様

> Aidea からコンパニオン（Claude セッション）にプロンプトを送信する仕組み

Backchannel（Claude → Aidea、ファイル経由）の逆方向。
PTY の `send(txt:)` で Claude セッションに直接プロンプトを送る。

---

## チャネルの全体像

| 方向 | 名前 | 手段 |
|------|------|------|
| Claude → Aidea | [Backchannel](../backchannels/backchannel.md) | ファイル書き出し (`.aidea/backchannels/`) |
| Aidea → Claude | **Frontchannel** | PTY に `send(txt:)` |

---

## 送信メカニズム

既存の `PersistentTerminalView.send(txt:)` を使用して PTY にプロンプトを送る。
ユーザーがキーボードで打ったのと同等。

```swift
claudeSessionState.terminalView.send(txt: message + "\r")
```

- Claude CLI は `\r` (CR) で送信を受け付ける
- セッションが未起動の場合は自動起動し、起動完了を待ってから送信

---

## 境界

### Always
- メッセージ送信は `send(txt:)` 経由で PTY に送る
- 未起動のコンパニオンにメッセージを送る場合は自動起動する
- メッセージ送信後、対象の Claude セッションをアクティブタブにする

### Never
- メッセージ内容をアプリ側で加工・変換しない（ユーザーの意図をそのまま Claude に伝える）
