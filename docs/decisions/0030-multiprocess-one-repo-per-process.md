---
title: "0030: 複数リポジトリはマルチプロセスで開き 1プロセス=1リポジトリとする"
description: 別々のリポジトリを同時に開く要件を、単一プロセス複数ウィンドウではなくマルチプロセス(1プロセス1リポジトリ)で実現し、同一リポジトリの二重起動は lock + 通知で排他して既存を前面化する決定
status: 提案
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-05
---

# 0030: 複数リポジトリはマルチプロセスで開き 1プロセス=1リポジトリとする

**日付**: 2026-06-05

## 背景

Aidea は単一ウィンドウ前提で設計されてきた ([architecture.md](../specs/architecture.md) の機能群関係図に「window/ アプリ全体 (1 ウィンドウ)」と明記)。開いているリポジトリ (projectRoot) は UserDefaults の単一キーで保持し、ワークスペース状態は `<projectRoot>/.aidea/workspace.json` にプロジェクト単位で保存する。

この構成では **別々のリポジトリを同時に開く**ことができない。後から別リポジトリを開くと、現在のウィンドウの projectRoot がそのまま差し替わる。

## 問題

複数リポジトリを並行作業したいニーズがある。だが単一プロセスで複数リポジトリを同居させようとすると、単一ウィンドウ前提に依存した箇所が一斉に競合する。

1. **状態オブジェクトの共有**: WorkspaceState / SessionRegistry / LayoutConfig / CompanionStore 等がアプリ起動時に 1 つずつ生成され、全ビューに配布される。複数リポジトリを 1 プロセスで持つと、これらを全て「ウィンドウ単位」に作り直す大改修が必要になる。
2. **グローバルイベントの競合**: キーイベントの local monitor (Cmd+W / Cmd+M / Ctrl+Tab 等) が複数ウィンドウで多重発火・誤ウィンドウ処理を起こす。
3. **`.aidea/` 固定パスの競合**: backchannels / scheduler / quickmemo / workspace.json などが projectRoot 基準の固定パスで、同一リポジトリを 2 つ開くと上書き・重複処理が発生する。

## 決定

複数リポジトリは **マルチプロセス方式**で開く。**1 プロセス = 1 リポジトリ = 1 ウィンドウ**を不変条件とする。

1. **新インスタンス起動**: 自バンドルを `open -n` (LaunchServices の新インスタンス起動) で別プロセスとして起動する。Apple 標準ツールのみで実現する ([ADR 0006](./0006-only-swiftterm-dependency.md))。
2. **projectRoot の受け渡し**: 起動引数 `--project-root <path>` で渡す (`open -n --args` 経由)。プロセス起動直後の `init` 時点で開くべきリポジトリが確定でき、現行の起動フローをほぼそのまま活かせる。`NSWorkspace.OpenConfiguration.arguments` 経由の引数渡しは空配列化する既知不具合があるため使わず、`open --args` の経路を用いる。URL スキーム `aidea://open-workspace?path=<percent-encoded-abspath>` は起動済みプロセスへの追加連携用に温存する (受信時は新プロセスを起動する)。
3. **同一リポジトリ排他**: `<projectRoot>/.aidea/.instance.lock` を所有権の単一情報源とする。lock は pid と一意トークンを記録し、atomic に取得 (排他生成 / flock) する。取得失敗時は既存プロセスが稼働中とみなし、新規起動を中止する。クラッシュ等で残った lock は「pid の生存」と「その pid が Aidea か (bundleId 照合)」で stale 判定して奪取する。
4. **既存の前面化**: 同一リポジトリを開こうとした際は、lock に記録されたトークンを名前空間にした DistributedNotificationCenter 通知で既存プロセスを前面化し、新プロセスは**黙って起動を中止**する (余計な通知やダイアログは出さない)。
5. **素起動 (projectRoot 未指定)**: Dock / Finder からの起動では、最近開いたリポジトリ (MRU) の一覧から選ばせる。
6. **「ディレクトリを開く」(⌘O)**: 常に新インスタンス起動に統一する。現在のウィンドウの projectRoot を差し替える従来挙動は廃止し、「1 プロセス = 1 リポジトリ」の不変条件を守る。

## 結果

- **NSEvent 競合の自然解消**: キーイベント local monitor はキーウィンドウを持つプロセスでのみ発火するため、プロセスが分かれれば自然に分離される。今後 global monitor を追加しない限り競合は起きない (global monitor 禁止を規約とする)。
- **状態共有問題の回避**: WorkspaceState / SessionRegistry / CompanionStore 等は別プロセスで完全に独立するため、ウィンドウ単位への作り直しが不要。
- **永続化の競合なし**: workspace.json は元々 projectRoot 単位で隔離済み。別リポジトリなら別パスになり、同一リポジトリは排他で二重起動しないため競合しない。
- **VOICEVOX 共有は許容**: VOICEVOX (localhost:50021) はクライアント接続のみでポートを bind しないため、複数プロセスが同一サーバを共有しても技術的に安全。複数プロセスの発話が混ざったときの「どのリポジトリのコンパニオンか」の出所表示は別途検討する。
- **Dock アイコン集約**: 子プロセスは親と同じ Dock アイコンに集約される。どのウィンドウがどのリポジトリかを判別できるよう、ウィンドウタイトルにリポジトリ名を出す UI 対応を併せて行う。
- **Session の射程が明確化**: [ADR 0013](./0013-session-as-first-class-object.md) の「Session を Window レベルで一意管理」「Session と State の分離」([ADR 0018](./0018-session-and-state-separation.md)) は、その射程が 1 プロセス内に閉じることが明確になる (Window = プロセス境界)。

## 不採用案

| 案 | 理由 |
|---|---|
| **単一プロセス複数ウィンドウ (WindowGroup マルチウィンドウ)** | WorkspaceState / SessionRegistry / 各種 local monitor / 状態オブジェクトを全て「ウィンドウ単位」に作り直す大改修が必要。排除したかった状態共有・NSEvent 競合がむしろ前面化する |
| **`NSWorkspace.openApplication` + `createsNewApplicationInstance` で起動し configuration.arguments で渡す** | completionHandler で起動成否を取れる利点はあるが、configuration.arguments は空配列化する既知不具合 (Apple Developer Forums thread 768433) がある。同じ引数渡しでも `open --args` の経路はこのバグの影響を受けず、`init` 時点で projectRoot を確定できるため `open -n --args` を採用した |
| **排他を DistributedNotification 単体で実現** | 「同一リポジトリを開く生存プロセスが本当に居るか」をタイムアウト往復で推測するしかなく、無応答=不在か遅延かを判別できず同時起動レースに弱い。lock の atomic 性で「先に掴んだ者勝ち」を厳密化する必要がある |
| **`LSMultipleInstancesProhibited` を設定** | これは複数ユーザセッション間のインスタンス制約であり、同一セッション内のマルチインスタンスを制御しない。意図と無関係なうえ将来の誤解の元になるため設定しない (=既定の複数インスタンス可を維持) |
| **一時受け渡しファイルで projectRoot を渡す** | 競合 (誰宛てか) ・後始末・読むタイミングの三重苦。単一パスの受け渡しには過剰でフラジャイル |

## 関連

- [docs/specs/window/multi-instance.md](../specs/window/multi-instance.md) — 本決定に基づくマルチプロセス起動・排他・MRU の振る舞い仕様
- [docs/specs/architecture.md](../specs/architecture.md) — 「1 プロセス = 1 ウィンドウ = 1 リポジトリ」へ更新
- [ADR 0006](./0006-only-swiftterm-dependency.md) — 外部依存を増やさず Apple 標準のみで実装する原則
- [ADR 0013](./0013-session-as-first-class-object.md) — Session を Window レベルで管理 (Window = プロセス境界の補足を追記)
- [ADR 0018](./0018-session-and-state-separation.md) — Session と State の分離 (射程が 1 プロセス内に閉じる)
- [ADR 0005](./0005-obsidian-hybrid.md) — URL スキーム + 直接ファイル操作のハイブリッド (aidea:// スキームの先行利用)
