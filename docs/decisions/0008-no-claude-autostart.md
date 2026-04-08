# 0008: ターミナルでは claude を自動起動しない（対話シェルで起動する）

**日付**: 2026-04-08
**状態**: 採用

## 背景
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

## 原因
- 認証は **Claude Max Account** で正しい (`ANTHROPIC_API_KEY` も未設定)
- にもかかわらず Anthropic 側が「サードパーティアプリ扱い」と判定していた
- 検証の結果、`zsh -l -c "..."` で **非対話シェル** から `claude` を exec すると判定が発動
- ターミナル内で **手動で `claude` を打つ場合は問題なし**
- `TERM_PROGRAM` 環境変数も空だったため、シェルの対話性 / TERM_PROGRAM のいずれか
  (もしくは両方) を Anthropic 側が見ていると推測される

## 判断
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

## 理由
1. プラン課金 (Claude Max) のまま使えるのが最優先
2. 「自動で claude が立ち上がる」便利さよりも、本来の枠で動くことの方が重要
3. 対話シェルから手動起動するルートは確実に問題が出ない実証済みの方法

## トレードオフ
- 起動のたびに `claude` を手で打つ手間がある
- → 将来的には「ボタン or キーバインドで claude を起動する」UI で補う余地あり

## 関連メモ
- `TERM_PROGRAM` を `Apple_Terminal` 等に偽装すれば自動起動でも回避できる可能性はあるが、
  Anthropic の利用規約上のグレーゾーンに踏み込むため不採用
- この問題は **Aidea から起動した場合のみ** 発生する。Terminal.app / iTerm2 から
  普通に `claude` を実行する分には問題なし
