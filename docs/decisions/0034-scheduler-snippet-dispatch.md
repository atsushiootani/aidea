---
title: "0034: スケジューラとスニペットの送信先・トリガーを拡張する"
description: スケジューラに cron 式トリガー (自作パーサ) を追加し、Terminal 送信先をタブ名で指定できるようにする。スニペットにも送信先を永続化して即実行できるようにし、タブ名解決をスケジューラと共通化する。スケジューラ⇄スニペットの変換は元を削除する「移動」にする決定
status: 提案
derived_from:
  - docs/decisions/0031-unified-scheduler-triggers-and-targets.md
  - docs/decisions/0033-snippet-scheduler-separation.md
  - docs/decisions/0006-only-swiftterm-dependency.md
syncs_with:
  - docs/specs/widgets/scheduler.md
  - docs/specs/widgets/snippets.md
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-20
---

# 0034: スケジューラとスニペットの送信先・トリガーを拡張する

**日付**: 2026-06-20

## 背景

スケジューラ ([ADR 0031](./0031-unified-scheduler-triggers-and-targets.md)) のトリガーは `scheduled` (定時・毎日) / `onLaunch` / `manual` のみで、「N 分ごと / N 時間ごと」の周期発火を表現できなかった。また送信先 `terminal` は常に新規タブで、特定のターミナルを狙えなかった。

スニペット ([ADR 0033](./0033-snippet-scheduler-separation.md)) は `name` + `command` の最小構成で、実行のたびに送信先ターミナルをメニューで選ぶ必要があり、「いつものターミナルへ即実行」ができなかった。さらにスケジューラ⇄スニペットの相互変換は元が残るため複製になり二重管理になりやすかった。

これらをまとめて、スケジューラ・スニペットの「いつ・どこへ送るか」を強化する。

## 決定

### 1. cron 式トリガー (スケジューラ)

- trigger に `cron(expr:)` を追加する。`expr` は標準 5 フィールド (`分 時 日 月 曜日`)。`scheduled` / `onLaunch` / `manual` と排他のタグ付きユニオン要素 ([ADR 0031](./0031-unified-scheduler-triggers-and-targets.md) の拡張容易性を活用)。
- **cron パーサは自前実装**する。[ADR 0006](./0006-only-swiftterm-dependency.md) により外部依存を増やさない。サポートは最小サブセット (`*` / `*/n` / `a` / `a-b` / `a-b/n` / `a,b,...`)。月名・曜日名・`@daily` 等のマクロ・秒フィールド・`L`/`W`/`#` 拡張は**非対応**。
- **壁時計アライン発火**。`*/5` は 0,5,10… 分、`0 */6 * * *` は 0/6/12/18 時ちょうど。起動/前回からの相対では発火しない。
- 日 (dom) と曜日 (dow) が両方制限されているときは **OR** で判定 (Vixie cron 互換)。曜日 `7`=日は `0` に正規化。
- cron ジョブは **状態管理 (lastRun / overdue) を持たない**。周期発火と「当日 1 回・取りこぼし通知」は相容れないため。逃した分は自動補完しない。
- ヘッダ widget には次回発火を集約する (cron も「次回待ち」に含める。overdue には含めない)。

### 2. Terminal 送信先のタブ名指定 (スケジューラ)

- `Target.terminal` に **タブ名 (`sessionTitle: String?`)** を持たせる。`nil` / 空 = 新規タブ (従来挙動)、値 = その**タブ名**のターミナルを狙う。
- 表示タイトル (`SessionRegistry.tabTitle(for:)`) が一致する生存中のターミナルタブへ送る。複数一致時は最初の 1 つ。
- **同名タブが無ければその名前で新規タブを作って送る** (フォールバック)。これにより発火のたびにタブが増えない。`nil`/空のときは名前なしの新規タブ。
- 永続化はタブ名をそのまま `sessionTitle` 文字列に保存。`nil` はキー省略。既存の `{ "type": "terminal" }` は `terminal(sessionTitle: nil)` として読む (後方互換)。
- 識別子に内部値 `SessionID` (tool + instance) もあるが、ユーザーが見て選ぶ手がかりとしては**タブ名**の方が直感的なため採用。

### 3. スニペットの送信先永続化 (スニペット)

- スニペットに送信先 `destination` を持たせる。値は **タブ名 (`tab`) / 新規タブ (`new`)** の 2 種。**未設定 (nil) はアクティブ端末** (アクティブが Terminal → そこ / 無ければ最初の Terminal / 無ければ新規) を既定とする。既存スニペットは省略 = アクティブ端末で従来どおり動く。
- `tab` のタブ名一致・同名フォールバックは、上記 2 の Terminal 送信と**同じ経路** (`SessionRegistry.tabTitle(for:)` + 共通ディスパッチ `sendToTerminal`) を使う。
- 実行 UI は「**主ボタン = 設定済み送信先へ即実行**」＋「**メニュー = その場限りで別の端末を明示選択** (アクティブ / 各ターミナル / 新規)」の 2 段。明示選択は一度きりで設定は変えない。

### 4. スケジューラ⇄スニペットの変換は「移動」 (両 widget)

- 変換は変換先を作成したうえで**元を削除する「移動」**にする。誤操作で失わないよう**確認ダイアログ**を挟む。
- 送信先のマッピング: `tab(title)` は相互にそのまま引き継ぐ。スケジューラの新規タブ (`terminal(sessionTitle: nil)`) ↔ スニペットの `new`。スニペットのアクティブ端末 (nil) はスケジューラに該当概念が無いため新規タブに倒す。スケジューラの `claude` ジョブをスニペット化する場合は Terminal 既定 (アクティブ端末)。

## 結果

- 「5 分ごと」「平日 9-18 時の 10 分ごと」等の周期実行が cron 1 行で表現できる。外部依存は増やさない。
- Claude (Companion 選択) と Terminal (タブ名指定) の操作感が揃う。同名タブが無くても新規作成で確実に実行され、タブが増殖しない。
- スニペットを「いつものターミナル」へワンクリックで送れ、必要なときだけ別端末に送れる。タブ名解決はスケジューラと完全共通。
- 変換が移動になり二重管理が起きない。確認ダイアログで誤変換を防ぐ。
- 既存の `scheduler.json` / `snippets.json` はマイグレーション無しで動く (新フィールドは任意)。
- 自前 cron パーサのサポート範囲は標準 cron の一部に留まる (名前・マクロ非対応)。タブ名は重複・変更されうる (複数一致は最初の 1 つに送る割り切り)。

## 不採用案

| 案 | 理由 |
|---|---|
| **周期発火を `interval(minutes:)` の独立種別にする** | 絞り込み (曜日・時間帯) を足すたびにフィールドが増え cron の再発明になる。表現力でも cron に劣る |
| **cron ライブラリを外部依存として導入** | [ADR 0006](./0006-only-swiftterm-dependency.md) の「外部依存は SwiftTerm のみ」に反する |
| **Terminal/スニペットの送信先を `SessionID` (instance 番号) で指定** | instance 番号は分かりにくく再利用もされる。タブ名の方が直感的 |
| **指定タブが無いとき名前なしの素のタブ / スキップ** | 前者は発火のたびにタブが増える。後者はジョブが黙って実行されない事故になる。同名で新規作成が最善 |
| **スニペット送信先設定に「アクティブ端末」も明示保存** | アクティブは「未設定時の既定」で十分。保存する実体は「タブ名 / 新規」に絞る方が素直 (nil = 既定) |
| **変換を複製のまま (元を残す) にする** | 二重管理になりどちらが正か分からなくなる。移動にする |

## 関連

- [docs/specs/widgets/scheduler.md](../specs/widgets/scheduler.md) — cron トリガー・Terminal タブ名指定を反映したスケジューラ仕様
- [docs/specs/widgets/snippets.md](../specs/widgets/snippets.md) — 送信先永続化・実行 UI・変換 (移動) を反映したスニペット仕様
- [ADR 0031](./0031-unified-scheduler-triggers-and-targets.md) — トリガー・送信先を1ジョブに統合した先行決定 (本 ADR はその拡張)
- [ADR 0033](./0033-snippet-scheduler-separation.md) — スニペットとスケジューラを別モデルで持つ決定
- [ADR 0006](./0006-only-swiftterm-dependency.md) — 外部依存を SwiftTerm のみに絞る (cron パーサ自作の根拠)
- `Aidea/Aidea/Sessions/SessionRegistry.swift` — タブ名 (customTitles / tabTitle) の管理。表示の正準は `Views/Layout/PaneView.swift` の displayLabel(for:)
