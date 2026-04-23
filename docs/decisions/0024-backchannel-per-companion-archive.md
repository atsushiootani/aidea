---
title: "0024: Backchannel メッセージは Companion 別ディレクトリに保存し削除しない"
description: speech / handoff / 将来の notify 等 Backchannel メッセージを .aidea/backchannels/<companion-index>/ 配下に書き出し、処理後も残して作業履歴として保全する決定
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

# 0024: Backchannel メッセージは Companion 別ディレクトリに保存し削除しない

**日付**: 2026-04-23

## 背景

Backchannel は Claude から Aidea への通信手段として、`.aidea/backchannels/` 配下にメッセージファイルを書き出す ([backchannel.md](../specs/backchannels/backchannel.md))。

これまでの配置と運用:

- speech / handoff / (将来の) notify 等すべてが `.aidea/backchannels/` **直下**にフラットに並ぶ
- speech は読み上げ完了後に削除、handoff は [ADR 0023](./0023-companion-handoff.md) 以降「残す」方針 (混在)
- どの Companion が書き出したかはファイル名から読み取れない

一方で、複数 Companion を同時に走らせて連携させるユースケース ([issue #77](https://github.com/atsushiootani/aidea/issues/77) / [issue #106](https://github.com/atsushiootani/aidea/issues/106)) が実装され、次の要求が顕在化した:

- 発言ログやハンドオフの経緯を Companion 別に追いたい
- 読み上げ済みメッセージも作業コンテキストの記録として残したい
- 同じ timestamp で複数 Companion が書き出したときにファイル衝突リスクがある

## 問題

1. **削除ポリシーの不統一**: speech は削除・handoff は保持。同じ Backchannel 内でルールが分岐しており、将来の新種別 (notify / action) を追加するたびに個別判断を迫られる
2. **送信元 Companion の不可視化**: 直下にフラットに並ぶと、どのファイルがどの Companion の発信かをファイル名だけで判別できない。履歴を追うには内容を 1 件ずつ開く必要がある
3. **作業履歴が消える**: speech ファイルは読み上げ後に消えるため、後から会話の流れや読み上げ内容を振り返れない。個人用ワークスペースとしての記録性が弱い
4. **衝突リスク**: 9 Companion 同時稼働時、同 timestamp で複数の speech-*.txt が生成されるとファイル名が衝突する

## 決定

Backchannel メッセージを **Companion 別サブディレクトリ** に配置し、**削除しない** ポリシーに統一する。

### ディレクトリ構造

```
.aidea/
└── backchannels/
    ├── 0/
    │   ├── speech-{timestamp}.txt     # Companion 0 の読み上げメッセージ
    │   └── handoff-{timestamp}.json   # Companion 0 が送信したハンドオフ
    ├── 1/
    │   ├── speech-*.txt
    │   └── handoff-*.json
    └── ... (0..8)
```

- `<companion-index>` は `0..8` の整数 (CompanionStore 9 枠固定 / ADR 0022)
- Claude は自分の index を `.aidea/claude/companions/<N>/instructions.md` のパス `<N>` から推論し、`<N>/` 配下に書き出す
- ディレクトリの作成タイミングは **Claude 書き出し時の mkdir -p 相当** (Aidea は事前作成しない)

### 削除ポリシー

- Backchannel メッセージファイル (speech / handoff / 将来の種別すべて) は Aidea 側で **削除しない**
- 処理後も `.aidea/backchannels/<n>/...` に残し、作業履歴・コンテキスト記録・監査用途として保全する
- 個別メッセージ仕様 (voicevox.md / handoff.md 等) は「残す」を共通原則として扱う
- ディスク使用量の管理はユーザ責務。自動ローテーション / 保持期間は MVP では実装しない

### ハンドラ通過条件

- Aidea は `.aidea/backchannels/` を再帰監視する (FSEvents のデフォルト再帰挙動を利用)
- `<companion-index>` が `0..8` のディレクトリ配下のファイルのみをハンドラに通す
- それ以外 (範囲外の数字 / 文字列ディレクトリ / `backchannels/` 直下) は警告ログのみで無視
- handoff の `from` フィールドは **必須** とし、パスの `<companion-index>` と一致することを Aidea 側で検証する (不一致時はログ + UI エラー、ファイルは残す)

### 移行方針

- **完全移行 (後方互換なし)**: 旧パス (`.aidea/backchannels/` 直下) に置かれたファイルは Aidea 側で認識しない
- Bundle 同梱の `.aidea/claude/speech.md` / `handoff.md` を新パス案内に差し替える (既存ユーザの `.aidea/claude/` は ADR 0022 のルールにより上書きしない)
- 既存ユーザは `.aidea/claude/speech.md` を手動で削除 → Aidea 再起動で新テンプレが再配布される (または手動で新形式に合わせて編集)

## 結果

- **記録性の向上**: 発言ログ・ハンドオフ経緯を Companion 別に追跡可能。ディレクトリを開けば即座に時系列で読める
- **ルールの単純化**: Backchannel 全種別で「残す」が原則になり、新種別追加時も個別判断が不要
- **衝突回避**: 同 timestamp の複数 Companion 書き出しでも、親ディレクトリが異なるため衝突しない
- **送信元の機械可読化**: Aidea 側も Claude 側も、ファイルパスから送信元 Companion を即座に判別できる (handoff の `from` 検証にも活用)
- **ユーザ負担**: ディスク容量はユーザ管理。旧 `.aidea/claude/speech.md` を持つ既存ユーザは再起動 or 手動更新が 1 回必要 (個人プロジェクトなので許容範囲)

## 不採用案

| 案 | 理由 |
|---|---|
| **speech だけ残す、他は個別判断** | Backchannel 内でルールが分岐したままになり、将来の新種別追加時に毎回判断コストが発生する。共通原則にした方が保守が楽 |
| **削除しつつ別ログファイルに追記** | 二重書き込みになり FSEvents のノイズが増える。原本をそのまま残すのが最もシンプル |
| **`<companion-index>` ではなく送信 Session の UUID ディレクトリ** | 同一 Companion が複数 Session を持つ時に履歴が分散する。Companion 単位で追跡したいユースケースに合わない。Companion index は ADR 0022 で 0..8 固定が保証されているのでパス要素として安定 |
| **並行サポート (新旧パス両監視) で過渡期運用** | 個人プロジェクトで実ユーザが限定的なため並行サポートのメンテコストが正当化できない。完全移行で仕様を単純化する |
| **Aidea が `<n>/` ディレクトリを事前作成** | Claude 側の書き出しで mkdir -p 相当が動くので不要な準備処理。Aidea の責務を最小化し、存在しない index のディレクトリが増えるのも避けられる |
| **自動ローテーション / 保持期間を仕様化** | MVP ではディスク圧迫の実例がなく、過剰設計。将来必要になれば別 ADR で追加する |

## 関連

- [docs/specs/backchannels/backchannel.md](../specs/backchannels/backchannel.md) — ディレクトリ構造・Always/Never・メッセージ種別の母仕様
- [docs/specs/backchannels/voicevox.md](../specs/backchannels/voicevox.md) — speech の実装仕様 (削除撤廃)
- [docs/specs/backchannels/handoff.md](../specs/backchannels/handoff.md) — handoff の実装仕様 (`from` 必須化 / パス検証)
- [docs/specs/aspects/persistence.md](../specs/aspects/persistence.md) — `.aidea/` 配下のデータ永続化
- ADR [0022: コンパニオン初期指示を外部 Markdown ファイルに分離する](./0022-companion-instructions-as-files.md) — Companion index 0..8 固定と指示書配置
- ADR [0023: コンパニオン間ハンドオフは Aidea オーケストレータ方式で実装する](./0023-companion-handoff.md) — handoff の「残す」方針を全 Backchannel に拡張
