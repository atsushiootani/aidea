---
title: "Backchannel: コンパニオン名簿の自動同期"
description: aidea.md 内のコンパニオン名簿セクションをマーカー領域で囲み、Aidea が `companions[].name` の変更に追従して自動更新する仕様
derived_from:
  - docs/specs/backchannels/handoff.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/companions/companion.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-03
---

# Backchannel: コンパニオン名簿の自動同期

> `.aidea/claude/aidea.md` の中にコンパニオン全員の index ↔ name 対応表を保持し、Aidea がワークスペース状態に追従して自動更新する。

ハンドオフ ([handoff.md](./handoff.md)) の `to` フィールドは index と name の両対応 ([ADR 0023](../../decisions/0023-companion-handoff.md))。送信元 Claude が他コンパニオンの name を自然言語で指定できるようにするため、9 体全員の index ↔ name 対応表を **aidea.md 内に常駐させる** ([issue #137](https://github.com/atsushiootani/aidea/issues/137))。

ユーザは `CompanionEditView` で各コンパニオンの name を自由にリネームできるため、aidea.md 側はリネームに追従しなければ陳腐化する。本仕様は aidea.md 内に Aidea 専用の名簿セクションをマーカーで囲んで配置し、Aidea が `CompanionStore.companions[].name` の変更に応じて自動的に書き換える機構を定める。

---

## 概要

- `.aidea/claude/aidea.md` の本文中に **マーカー領域**を 1 箇所設け、その内側にコンパニオン 9 体全員の index ↔ name 対応表を Markdown リストで保持する
- マーカー外はユーザの自由編集領域。Aidea は触らない
- マーカー内は Aidea の自動管理領域。`CompanionStore.companions[].name` が更新された瞬間に書き換える
- Bundle 同梱テンプレ (`Aidea/Resources/Backchannels/aidea.md`) にもマーカー + デフォルト名のリストを最初から含める。新規プロジェクトはマーカー込みで `.aidea/claude/aidea.md` がコピーされる
- 旧版から移行した既存ユーザの aidea.md にマーカーが無い場合は、起動時に **末尾へ自動追記** する (本文を破壊しない)

---

## マーカー仕様

### マーカー文字列

```
<!-- aidea:companions:start -->
...
<!-- aidea:companions:end -->
```

- `<!-- ... -->` は Markdown では HTML コメント扱いとなり、レンダリング結果には現れない
- `aidea:` プレフィックスは Aidea が管理する自動更新領域の名前空間 (将来別の自動更新セクションを追加するときも同じ慣例を使う)
- start / end は **同一行に単独で**置く。前後のテキストやインデントを付けない (パーサ簡素化)

### マーカー内のフォーマット

マーカー内側は次の Markdown リストで構成する:

```markdown
- 0: <name-0>
- 1: <name-1>
- 2: <name-2>
- 3: <name-3>
- 4: <name-4>
- 5: <name-5>
- 6: <name-6>
- 7: <name-7>
- 8: <name-8>
```

- 必ず 9 行 (index 0..8 全て)
- `<name-N>` は `CompanionStore.companions[N].name` の値そのまま
- 行頭 `- ` 固定 (BulletList)、ハイフン後ろ半角スペース 1 つ
- index と name の区切りは `: ` (半角コロン + 半角スペース)
- name 内に Markdown 特殊文字が含まれていてもエスケープしない (生の文字列として書く)

### マーカー外のフォーマット (テンプレ提示)

aidea.md 全体の構造は次のとおり (Bundle 同梱の `Aidea/Resources/Backchannels/aidea.md` テンプレ):

```markdown
# Aidea Backchannel 指示

あなたは Aidea ワークスペース内のターミナルで動作しています。

必要に応じて以下の機能ファイルを読んで従ってね (段階的開示)。

- 音声で返答したいとき → `.aidea/claude/speech.md`
- 他の Companion にタスクを受け渡したいとき → `.aidea/claude/handoff.md`

## ワークスペースのコンパニオン一覧

ハンドオフ (handoff.md) で `to` に name を指定したいときは、下の一覧から名前を引いてね。

> この一覧は Aidea が自動で書き換えるよ。直接編集しても上書きされちゃうから、
> 名前を変えたいときはヘッダのアイコン下の名前ラベルをクリックして編集してね。

<!-- aidea:companions:start -->
- 0: Companion 1
- 1: Companion 2
- 2: Companion 3
- 3: Companion 4
- 4: Companion 5
- 5: Companion 6
- 6: Companion 7
- 7: Companion 8
- 8: Companion 9
<!-- aidea:companions:end -->
```

説明文 (見出し・段落・引用) はテンプレ初期値であり、ユーザが書き換えても Aidea は触らない。

---

## 更新タイミング

`CompanionRosterWriter` の roster 書き込みは以下の 2 経路から呼び出す:

| 経路 | タイミング | 呼び出し元 |
|---|---|---|
| **スナップショット復元 (起動時 + リロード時)** | `WorkspaceSnapshotManager` の apply 末尾、`CompanionStore.companions` セット直後 | `AideaApp` 起動シーケンス経由 |
| **コンパニオンの編集確定時** | `CompanionStore` のコンパニオン更新処理で `companions[index].name` が変化した瞬間 | `CompanionEditView` の OK ハンドラ |

`AideaApp` の起動シーケンス上、`BackchannelSetup` が `WorkspaceSnapshotManager` の apply より先に走ることで `.aidea/claude/aidea.md` がコピー済みになる。Bundle 同梱テンプレに既にデフォルトの roster ブロックが含まれているため、apply 末尾の `writeRoster` 呼び出しは差分なし (no-op) で完結することが多い。`workspace.json` でユーザがコンパニオンをリネーム済みの場合のみ、apply の末尾で aidea.md の roster がユーザ設定に追従する。

両経路とも `CompanionStore.companions` の最新スナップショットを渡す。`writeRoster` は内部で差分を判定し、aidea.md に書き出す内容が現在と同一なら **書き込みをスキップ** する (mtime 更新を避け、不要な FSEvents を発生させない)。

### コンパニオン更新時のフック

`CompanionStore` のコンパニオン更新処理自身は永続化や副作用を持たない (純粋なインメモリ更新)。aidea.md への反映は呼び出し側で行う:

- `CompanionEditView` の編集確定 → コンパニオン更新処理 → 直後に `CompanionRosterWriter` の roster 書き込みを呼ぶ
- セッション紐付けのみ変更する操作 (bind / unbind / unbindSession) では呼ばない (name は変わらないため)

`WorkspaceSnapshotManager` 等からコンパニオン更新処理を経由して name が変わるパスでも、apply 末尾で writeRoster を一度だけ呼ぶことで包括的にカバーされる。

---

## 書き換えアルゴリズム

`CompanionRosterWriter.writeRoster(projectRoot:companions:)` の挙動:

1. `aideaURL = projectRoot + ".aidea/claude/aidea.md"` を解決
2. ファイルが存在しなければ **no-op** (BackchannelSetup が未実行 or ユーザが削除した。次回 setup 時に再生成される)
3. 既存ファイルを UTF-8 で読み込む
4. **マーカーが両方含まれる場合**:
   - 先頭の `<!-- aidea:companions:start -->` 行と末尾の `<!-- aidea:companions:end -->` 行を境界とし、その**内側を 9 行の roster リストで置き換える**
   - マーカー行自体は維持 (削除も移動もしない)
   - マーカーが複数組ある場合は最初の組のみ対象 (異常系。本来 1 組のみ)
5. **マーカーが片方しかない / 両方ない場合**:
   - ファイル末尾に空行 1 つ + 推奨セクション (テンプレと同じ「## ワークスペースのコンパニオン一覧」見出し以降) を追記する
   - 既存の本文は一切触らない
6. 生成した新内容が **既存ファイルと完全に同一**であれば書き込まずに終了 (FSEvents 抑止)
7. 異なる場合のみ atomic 書き込み (`Data.write(to:options: .atomic)`) で aidea.md を上書き

### 文字コード・改行コード

- 文字コード: UTF-8 (BOM なし)
- 改行コード: 既存ファイルの改行コードを尊重する (LF / CRLF を判定し、新しい roster ブロックも同じ改行で書く)
- 末尾改行: 既存ファイルが末尾改行ありならあり / なしならなし (尊重)

---

## ユーザ編集との衝突

| 編集対象 | 挙動 |
|---|---|
| マーカー**外**の本文を書き換え | Aidea は完全に保護。書き戻しもしない |
| マーカー**内**の roster を書き換え | 次回 `writeRoster` 実行時に Aidea 由来の値で上書き (警告コメントで予告済み) |
| マーカー行自体を削除 | 次回 `writeRoster` 実行時にファイル末尾へ追記される (本文は破壊しない) |
| 片方のマーカーだけ残った状態 | 「両方ない」と同じ扱いで末尾に追記 (壊れたマーカーは触らない) |
| aidea.md ファイルそのものを削除 | 次回 `BackchannelSetup` 実行時に Bundle テンプレからコピー (マーカー込み) |

ユーザが「自動更新を止めて手動管理に切り替えたい」場合は、マーカーを削除すればその後 Aidea は本文中央には書かなくなる (末尾追記が走るので、追記されたセクションも削除すれば実質的に止められる)。**自動更新の完全 off 設定は MVP では持たない** (将来の拡張ポイント)。

---

## 受信側 Claude の活用方法

`.aidea/claude/aidea.md` は Companion `instructions.md` 経由で全コンパニオンが読み込む共通指示書。Claude は本文を読み、ハンドオフ送信時に「main-chan に振って」「review-chan にレビュー依頼」のような自然言語指示を name に変換する際に roster セクションを参照する。

handoff.md には次の一文を追記する (本仕様への参照)。本文の細部は handoff.md 側で記述するが、ハンドオフを宣言した Companion は aidea.md 内の roster を読めば全員の name を把握できることを明示する。

---

## Aidea 側の実装コンポーネント

| コンポーネント | 配置 | 責務 |
|---|---|---|
| `CompanionRosterWriter` | aidea.md のマーカー領域を読み書きする純関数的ヘルパ。プロジェクトルートとコンパニオン設定リストを受け取り、必要に応じて aidea.md を更新する |
| `WorkspaceSnapshotManager` | スナップショット復元後にロスター書き込みを実行する |
| `CompanionEditView` | コンパニオン設定を更新した後にロスター書き込みを実行する |

`CompanionRosterWriter` は外部依存を持たず、`Foundation` のみで完結する。VOICEVOX や FSEvents との連携は不要。

### Bundle テンプレの更新

`Aidea/Resources/Backchannels/aidea.md` (Bundle 同梱) を本仕様の「マーカー外のフォーマット (テンプレ提示)」に書き換える。新規プロジェクトはマーカー込みのテンプレが `.aidea/claude/aidea.md` にコピーされる。

旧版から移行した既存ユーザの aidea.md は **上書きしない** (`BackchannelSetup` の既存方針)。代わりに起動時の `writeRoster` がマーカー追記モードで末尾にセクションを追加する。

---

## 関連

- [ADR 0023: コンパニオン間ハンドオフ](../../decisions/0023-companion-handoff.md) — name 指定の正当化根拠
- [handoff.md](./handoff.md) — `to` フィールドのスキーマと name 解決ルール
- [companion.md](../companions/companion.md) — `CompanionConfig.name` のデータモデル
- [backchannel.md](./backchannel.md) — Bundle テンプレと `BackchannelSetup` の責務
- [issue #137](https://github.com/atsushiootani/aidea/issues/137) — 本仕様の起票チケット
