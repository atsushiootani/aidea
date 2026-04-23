---
title: "0023: コンパニオン間ハンドオフは Aidea オーケストレータ方式で実装する"
description: コンパニオン間でタスクを受け渡すハンドオフ機能を、Backchannel ファイル + Aidea 側 FSEvents 監視 + Frontchannel 再送信で実装する決定
status: 提案
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# 0023: コンパニオン間ハンドオフは Aidea オーケストレータ方式で実装する

**日付**: 2026-04-23

## 背景

複数のコンパニオンを連携させてパイプライン的にタスクを流したいユースケースがある ([issue #77](https://github.com/atsushiootani/aidea/issues/77))。代表例:

- concier-chan が今日の TODO を確認 → 優先度の高い issue を main-chan に渡して実装開始させる
- main-chan がコードを書き終わる → review-chan にレビューを依頼する
- review-chan がレビュー結果を書き終わる → main-chan に差し戻す

いずれも「送信元 Companion が次のアクションを送信先 Companion に引き渡す」という構造を持つ。既存の Backchannel (Claude → Aidea) と Frontchannel (Aidea → Claude) の組み合わせで、自然に扱える対象。

## 問題

Claude のセッション間で直接メッセージを流すのは現実的ではない:

1. **Claude CLI は対話駆動が前提** ([ADR 0008](./0008-no-claude-autostart.md))。送信先の Claude が「ファイルを監視してメッセージが来たら動く」ような自律ループを持つと、プロンプトが常駐してトークンを消費し続ける。
2. **送信元と送信先が `.aidea/` 経由で直接通信する**と、プロトコル設計が Claude 側 (2 インスタンス以上) に散らばり、ユーザが編集する指示書が複雑化する。
3. **各 Companion のディスパッチ判断を Aidea 側で一元化しないと**、宛先の自動起動やタブの自動アクティブ化ができない (Claude 側から PTY 制御や他 Session への干渉は不可)。

既存の Frontchannel ([docs/specs/frontchannels/frontchannel.md](../specs/frontchannels/frontchannel.md)) は「Aidea → 特定の Claude セッションへ PTY `send(txt:)`」を担うため、ハンドオフの送信経路としてそのまま再利用できる。

## 決定

**Aidea をオーケストレータとする**。送信元 Companion は `.aidea/backchannels/handoff-{timestamp}.json` を書き出すだけで完結し、Aidea が以下を担う:

1. **受信**: FSEvents で `.aidea/backchannels/handoff-*.json` を監視 (既存の SpeechWatcher と同じパターン)
2. **解釈**: JSON をデコードし、`to` フィールド (index / name) から宛先 Companion を解決
3. **配送**: 宛先の Claude セッションが未起動なら自動起動し、`ClaudeSessionState.sendMessage(".aidea/backchannels/{filename} の作業をやってね")` で **ファイル参照メッセージ** を PTY に送信する (Frontchannel の再利用)。`message` 本文は PTY には流さず、受信側 Claude が handoff-*.json を読んで取得する
4. **UI 遷移**: 宛先タブを自動アクティブ化 (既存 Frontchannel ルールと同じ)
5. **後片付け**: handoff-*.json は残す (受信側 Claude が読むため。ハンドオフ履歴のログとしても機能)

送信元 Claude 側には **待機ループを作らない**。ハンドオフを書き出したら通常どおりターンを終え、結果を待つかどうかはユーザの運用 (次ターンで質問する等) に委ねる。

### なぜ Frontchannel に本文を直送せずファイル参照にするか

`message` 本文が長文・改行・コードブロックを含むと、PTY ペーストでの文字化けや改行誤認・ターミナル制御文字干渉のリスクが増える。本文は backchannel (ファイル) に集約し、frontchannel (PTY) は固定文言の参照通知だけに抑える設計にすることで:

- PTY に流すテキストが常に `.aidea/backchannels/handoff-{name}.json の作業をやってね` という 1 行に収まる (エスケープ・改行問題を回避)
- 受信側 Claude はファイルを読む標準操作で本文を取得するため、構造化データや長文を安全に運べる
- `.aidea/backchannels/` にハンドオフファイルが残り、ハンドオフ経緯を事後に参照・再実行しやすい

この分離は Backchannel/Frontchannel の既存原則 (Claude → Aidea はファイル / Aidea → Claude は PTY send) を壊さず、ハンドオフ本文を「Backchannel に置いておいて、Frontchannel は通知だけ」という明確な責務で配置できる。

### 機能宣言チェーン (既存 Backchannel 規約に乗せる)

`.aidea/claude/handoff.md` を新設し Bundle 同梱する ([ADR 0022](./0022-companion-instructions-as-files.md) と同じ配布方式)。内容はハンドオフ JSON の書き方と送信例。

ハンドオフ機能を使いたい Companion は `instructions.md` 冒頭で参照する:

```markdown
.aidea/claude/aidea.md と .aidea/claude/handoff.md を読んで従ってね。
```

参照を書かない Companion はハンドオフ機能を持たない (既存の speech.md と同じ運用)。

### 宛先解決 (index と name の両対応)

`to` フィールドは **index (0..8)** または **name 文字列** のどちらでも受け付ける:

- **index 指定** (`"to": 0`): `CompanionStore.companions[0]` を直接参照
- **name 指定** (`"to": "main-chan"`): `CompanionStore.companions` を走査し、`name` の大文字小文字・前後空白を無視した最初のマッチの index を使う
- **解決失敗時**: ログ出力してファイル削除、送信はスキップ (UI 通知は MVP では省略)

name 指定を許容する理由は、送信元 Claude のプロンプト文面がユーザにとって自然になるため (例: 「main-chan にハンドオフしてね」)。index も並行サポートすることで、name 衝突やリネームで壊れない運用経路も確保する。

## 結果

- **Claude 側のトークン節約**: 宛先 Companion は「起動していない or 直前のターンで止まっている」状態で OK。Aidea が必要な瞬間だけ再始動する
- **対話駆動原則の維持**: 各 Claude セッションは引き続き 1 ターン = 1 入力 → 1 応答のまま。待機ループ・常駐プロンプトが増えない
- **Backchannel 哲学の一貫性**: Claude → Aidea はファイル、Aidea → Claude は PTY send。既存の 2 チャネルをそのまま組み合わせる
- **ユーザ編集体験**: ハンドオフを使うか使わないかは Companion ごとの `instructions.md` の 1 行で切り替えられる (speech.md / aidea.md と同じ)
- **段階的拡張性**: 将来 `handoff-{timestamp}.json` に `hops` / `payload` などのフィールドを足しても、既存 Companion の設定を壊さない

## 不採用案

| 案 | 理由 |
|---|---|
| **宛先 Claude が FSEvents 相当の待機ループを持つ** | Claude CLI が対話駆動前提 (ADR 0008) で、常時ターンを消費するとトークンコストとコンテキスト汚染が深刻。ユーザが「何してるの？」と聞いても「待ってる」と答えるだけの無駄なターンが残る |
| **Aidea が内部チャネル (NSNotification / Combine) だけで中継する** | `.aidea/backchannels/` にファイルが残らないため、Claude 側ログからハンドオフ経緯を追えない。監査性と他ツール連携 (例: 外部 CLI からのハンドオフ投入) が失われる |
| **JSON ではなくテキストフォーマット (`to: ...` ヘッダ付き)** | speech.txt と揃えて「最初の行はメタデータ」にする案。メッセージ本文に改行やコードブロックを含めたいとき不自由。`handoff` は構造化された宛先情報を持つため JSON が素直 |
| **宛先は name のみ / index のみ** | name のみだと Companion をリネームした瞬間に壊れる。index のみだと送信元 Claude のプロンプトが「companion-3 にハンドオフ」のようにユーザにとって不自然。両方サポートして使い分けられる方が運用上柔軟 |
| **ハンドオフを `.aidea/claude/companions/<index>/` 内に置き、Companion ごとにファイル分離** | Aidea が全 Companion ディレクトリを監視する必要があり FSEvents 設定が増える。`.aidea/backchannels/` 1 箇所に集約する既存モデルと揃える方が単純 |
| **既存 Speech / Notify と統合した汎用 Action JSON** | backchannel.md が将来予定として挙げていた `action-*.json` と同じ粒度にする案。ただしハンドオフ固有の概念 (宛先 / message 本文) を Action 内のサブ型として扱うと、Dispatcher の分岐が複雑になる。先に Handoff を独立したメッセージ種別として実装してから、類似パターンが増えた段階で汎用化を再検討する |
| **`message` 本文を Frontchannel に直接 PTY 送信する** | 長文・改行・コードブロック・コマンドを含む `message` を PTY に直接流すと、ペースト時の文字化け・改行誤認・ターミナル制御文字干渉が発生する。本文は Backchannel (ファイル) に集約し、Frontchannel は固定文言の参照通知だけに留める方がロバストで、構造化データを安全に運べ、監査性も高まる |

## 関連

- [docs/specs/backchannels/handoff.md](../specs/backchannels/handoff.md) — Handoff の完全仕様 (JSON スキーマ / Watcher / Dispatcher)
- [docs/specs/backchannels/backchannel.md](../specs/backchannels/backchannel.md) — メッセージ種別の母仕様
- [docs/specs/frontchannels/frontchannel.md](../specs/frontchannels/frontchannel.md) — PTY `send(txt:)` による送信経路 (ハンドオフで再利用)
- [docs/specs/companions/companion.md](../specs/companions/companion.md) — 起動フロー / `ClaudeSessionState.companionPrompt`
- ADR [0008: ターミナルでは claude を自動起動しない](./0008-no-claude-autostart.md) — 対話駆動前提
- ADR [0022: コンパニオン初期指示を外部 Markdown ファイルに分離する](./0022-companion-instructions-as-files.md) — 機能宣言チェーンの配布方式
