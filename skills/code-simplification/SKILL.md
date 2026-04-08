---
name: code-simplification
description: Simplifies code for clarity. Use when refactoring code for clarity without changing behavior. Use when code works but is harder to read, maintain, or extend than it should be. Use when reviewing code that has accumulated unnecessary complexity.
---

# コードシンプル化

> [Claude Code Simplifier plugin](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-simplifier/agents/code-simplifier.md) にインスパイアされた。任意のAIコーディングエージェント向けに、モデル非依存のプロセス駆動スキルとしてここに適応。

## 概要

挙動を正確に保ちながら複雑さを減らしてコードを簡素化する。目標は行数を減らすことではない――読み、理解し、変更し、デバッグしやすいコードにすること。すべてのシンプル化は単純なテストを通過しなければならない: 「新しいチームメンバーは元のコードより速くこれを理解できるか?」

## 使うとき

- 機能が動きテストが通った後、実装が必要以上に重く感じるとき
- コードレビューで読みやすさや複雑さの問題が指摘されたとき
- 深くネストしたロジック、長い関数、不明瞭な名前に遭遇したとき
- 時間的プレッシャーで書かれたコードをリファクタリングするとき
- 複数ファイルに散らばった関連ロジックを統合するとき
- 重複や不整合を導入した変更をマージした後

**使わないとき:**

- コードが既にクリーンで読みやすい――ただシンプル化のためにシンプル化しない
- コードが何をするかまだ理解していない――理解してから簡素化する
- コードがパフォーマンスクリティカルで、「よりシンプルな」版が計測可能に遅くなる
- モジュール全体を書き直そうとしている――捨てるコードをシンプル化するのは無駄

## 5つの原則

### 1. 挙動を正確に保つ

コードが何をするかではなく、どう表現するかだけを変える。すべての入力、出力、副作用、エラー挙動、エッジケースは同一でなければならない。簡素化が挙動を保つかわからないなら、しない。

```
すべての変更の前に問え:
→ すべての入力に対して同じ出力を生むか?
→ 同じエラー挙動を維持するか?
→ 同じ副作用と順序を保つか?
→ すべての既存テストが変更なしで通るか?
```

### 2. プロジェクト慣習に従う

シンプル化とは、外部の好みを押し付けることではなく、コードベースとの一貫性を高めること。簡素化前に:

```
1. CLAUDE.md / プロジェクト慣習を読む
2. 近隣のコードが類似パターンをどう扱うか調べる
3. プロジェクトのスタイルに合わせる:
   - import順序とモジュールシステム
   - 関数宣言スタイル
   - 命名規約
   - エラーハンドリングパターン
   - 型アノテーションの深さ
```

プロジェクトの一貫性を壊す簡素化はシンプル化ではない――ただの混乱。

### 3. 巧妙さより明確さ

コンパクトな版が理解に一瞬の停止を要するなら、明示的なコードの方が良い。

```typescript
// 不明瞭: 密な三項チェーン
const label = isNew ? 'New' : isUpdated ? 'Updated' : isArchived ? 'Archived' : 'Active';

// 明確: 読みやすいマッピング
function getStatusLabel(item: Item): string {
  if (item.isNew) return 'New';
  if (item.isUpdated) return 'Updated';
  if (item.isArchived) return 'Archived';
  return 'Active';
}
```

```typescript
// 不明瞭: インラインロジック付きの連鎖reduce
const result = items.reduce((acc, item) => ({
  ...acc,
  [item.id]: { ...acc[item.id], count: (acc[item.id]?.count ?? 0) + 1 }
}), {});

// 明確: 名付けされた中間ステップ
const countById = new Map<string, number>();
for (const item of items) {
  countById.set(item.id, (countById.get(item.id) ?? 0) + 1);
}
```

### 4. バランスを保つ

シンプル化には失敗モードがある: 過剰な簡素化。次の罠に注意:

- **インライン化しすぎ** ――概念に名前を与えていたヘルパーを削除すると呼び出し側が読みにくくなる
- **無関係ロジックの結合** ――2つのシンプルな関数を1つの複雑な関数にマージするのはシンプルではない
- **「不要な」抽象を削除** ――一部の抽象は複雑さではなく拡張性やテスタビリティのために存在する
- **行数を最適化** ――行数が少ないのが目標ではない、理解しやすさが目標

### 5. 変更範囲に絞る

デフォルトで最近変更されたコードを簡素化する。明示的に範囲拡大を求められない限り、関連のないコードのドライブバイリファクタリングを避ける。範囲外の簡素化は差分のノイズとなり意図しないリグレッションの危険を生む。

## シンプル化プロセス

### ステップ1: 触れる前に理解する（Chesterton's Fence）

何かを変更・削除する前に、なぜ存在するかを理解する。これがChesterton's Fence: 道をふさぐ柵を見て理由がわからないなら、壊すな。まず理由を理解し、それから理由がまだ当てはまるかを判断する。

```
簡素化前に答えよ:
- このコードの責務は何か?
- 何が呼び、何を呼ぶか?
- エッジケースとエラーパスは?
- 期待される挙動を定義するテストはあるか?
- なぜこう書かれたか?（パフォーマンス? プラットフォーム制約? 歴史的理由?）
- git blameを確認: このコードの元の文脈は?
```

これらに答えられないなら、シンプル化する準備ができていない。先にもっとコンテキストを読め。

### ステップ2: 簡素化機会の特定

次のパターンをスキャン――それぞれ具体的なシグナルであって、漠然とした臭いではない:

**構造的複雑さ:**

| パターン | シグナル | シンプル化 |
|---------|--------|----------------|
| 深いネスト（3段以上） | 制御フローが追いにくい | 条件をガード節やヘルパー関数に抽出 |
| 長い関数（50行以上） | 複数の責務 | 説明的名前の焦点を絞った関数に分割 |
| ネストした三項 | 読むのにメンタルスタックが必要 | if/elseチェーン、switch、ルックアップオブジェクトに置換 |
| ブーリアン引数フラグ | `doThing(true, false, true)` | オプションオブジェクトや別関数に置換 |
| 繰り返す条件 | 同じ `if` チェックが複数箇所 | 命名された述語関数に抽出 |

**命名と読みやすさ:**

| パターン | シグナル | シンプル化 |
|---------|--------|----------------|
| ジェネリック名 | `data`, `result`, `temp`, `val`, `item` | 内容を説明するようリネーム: `userProfile`, `validationErrors` |
| 省略名 | `usr`, `cfg`, `btn`, `evt` | 略語が普遍的（`id`, `url`, `api`）でない限り完全語を使う |
| 誤解を招く名前 | `get` という関数が状態を変える | 実際の挙動を反映するようリネーム |
| 「何を」説明するコメント | `count++` の上の `// increment counter` | 削除――コードで十分明確 |
| 「なぜ」説明するコメント | `// Retry because the API is flaky under load` | 残す――コードでは表現できない意図を持つ |

**冗長:**

| パターン | シグナル | シンプル化 |
|---------|--------|----------------|
| 重複ロジック | 5行以上が複数箇所で同じ | 共有関数に抽出 |
| デッドコード | 到達不能分岐、未使用変数、コメントアウトブロック | 削除（本当にデッドか確認後） |
| 不要な抽象 | 価値を加えないラッパー | ラッパーをインライン化、下層関数を直接呼ぶ |
| 過剰設計パターン | factory-of-factory、strategy-with-one-strategy | シンプルな直接アプローチに置換 |
| 冗長な型アサーション | 既に推論された型へのキャスト | アサーションを削除 |

### ステップ3: 段階的に変更を適用

一度に1つずつシンプル化する。各変更後にテストを実行。**リファクタリング変更は機能やバグ修正とは別にサブミットする。** リファクタと機能追加のPRは2つのPR――分ける。

```
各シンプル化について:
1. 変更を行う
2. テストスイート実行
3. テスト通過 → コミット（または次へ）
4. テスト失敗 → 戻して再検討
```

複数のシンプル化を1つの未テスト変更にまとめない。何かが壊れたらどれが原因か知る必要がある。

**500ルール:** リファクタリングが500行以上に触れるなら、手動でなく自動化（codemod、sedスクリプト、AST変換）に投資する。その規模の手動編集はエラーが起きやすくレビューも疲れる。

### ステップ4: 結果を検証

すべての簡素化後、一歩引いて全体を評価する:

```
変更前と変更後を比較:
- 簡素化版は本当に理解しやすくなったか?
- コードベースと矛盾するパターンを導入していないか?
- 差分はクリーンでレビュー可能か?
- チームメイトならこの変更を承認するか?
```

「シンプル化」版が理解・レビューしにくいなら戻す。すべての簡素化の試みが成功するわけではない。

## 言語固有ガイダンス

### TypeScript / JavaScript

```typescript
// シンプル化: 不要な async ラッパー
// 変更前
async function getUser(id: string): Promise<User> {
  return await userService.findById(id);
}
// 変更後
function getUser(id: string): Promise<User> {
  return userService.findById(id);
}

// シンプル化: 冗長な条件代入
// 変更前
let displayName: string;
if (user.nickname) {
  displayName = user.nickname;
} else {
  displayName = user.fullName;
}
// 変更後
const displayName = user.nickname || user.fullName;

// シンプル化: 手動配列構築
// 変更前
const activeUsers: User[] = [];
for (const user of users) {
  if (user.isActive) {
    activeUsers.push(user);
  }
}
// 変更後
const activeUsers = users.filter((user) => user.isActive);

// シンプル化: 冗長なブーリアンreturn
// 変更前
function isValid(input: string): boolean {
  if (input.length > 0 && input.length < 100) {
    return true;
  }
  return false;
}
// 変更後
function isValid(input: string): boolean {
  return input.length > 0 && input.length < 100;
}
```

### Python

```python
# シンプル化: 冗長な辞書構築
# 変更前
result = {}
for item in items:
    result[item.id] = item.name
# 変更後
result = {item.id: item.name for item in items}

# シンプル化: 早期returnによるネスト条件
# 変更前
def process(data):
    if data is not None:
        if data.is_valid():
            if data.has_permission():
                return do_work(data)
            else:
                raise PermissionError("No permission")
        else:
            raise ValueError("Invalid data")
    else:
        raise TypeError("Data is None")
# 変更後
def process(data):
    if data is None:
        raise TypeError("Data is None")
    if not data.is_valid():
        raise ValueError("Invalid data")
    if not data.has_permission():
        raise PermissionError("No permission")
    return do_work(data)
```

### React / JSX

```tsx
// シンプル化: 冗長な条件レンダリング
// 変更前
function UserBadge({ user }: Props) {
  if (user.isAdmin) {
    return <Badge variant="admin">Admin</Badge>;
  } else {
    return <Badge variant="default">User</Badge>;
  }
}
// 変更後
function UserBadge({ user }: Props) {
  const variant = user.isAdmin ? 'admin' : 'default';
  const label = user.isAdmin ? 'Admin' : 'User';
  return <Badge variant={variant}>{label}</Badge>;
}

// シンプル化: 中間コンポーネントを通るプロップドリリング
// 変更前 — contextまたはcompositionが良い解決策か検討。
// これは判断事項――自動リファクタせずフラグする。
```

## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| 「動いてるから触る必要ない」 | 読みにくい動くコードは壊れたとき直しにくい。今シンプル化すれば将来の変更すべてで時間を節約。 |
| 「行数が少ない方が常にシンプル」 | 1行のネスト三項は5行のif/elseよりシンプルではない。シンプルさは理解速度であって行数ではない。 |
| 「ついでに関連のないこのコードもシンプル化する」 | 範囲外のシンプル化はノイジーな差分と意図しないリグレッションの危険を生む。集中せよ。 |
| 「型が自己文書化してる」 | 型は構造を文書化するが意図はしない。よく名付けられた関数は型シグネチャが「何を」説明するより「なぜ」をうまく説明する。 |
| 「この抽象は後で役立つかも」 | 投機的抽象を保存するな。今使われていないなら価値なしの複雑さ。削除し必要時に再追加。 |
| 「元の作者には理由があったはず」 | かもしれない。git blameを確認――Chesterton's Fenceを適用。だが累積した複雑さはしばしば理由がない、プレッシャー下での反復の残滓。 |
| 「この機能追加のついでにリファクタ」 | リファクタと機能作業を分離。混在した変更はレビュー、リバート、履歴理解が難しい。 |

## レッドフラグ

- テストを修正しないと通らないシンプル化（おそらく挙動を変えた）
- 元より長く追いにくくなった「シンプル化」コード
- プロジェクト慣習ではなく自分の好みに合わせるリネーム
- 「コードがきれいになるから」エラーハンドリングを削除
- 完全に理解していないコードをシンプル化
- 多くのシンプル化を1つの大きなレビューしにくいコミットにまとめる
- 依頼されていないのに現在のタスクの範囲外のコードをリファクタ

## 検証

シンプル化パス完了後:

- [ ] すべての既存テストが変更なしで通る
- [ ] ビルドが新しい警告なしで成功
- [ ] リンター/フォーマッタが通る（スタイル後退なし）
- [ ] 各シンプル化がレビュー可能な段階的変更
- [ ] 差分がクリーン――関連のない変更が混在していない
- [ ] シンプル化されたコードがプロジェクト慣習に従う（CLAUDE.md等でチェック）
- [ ] エラーハンドリングが削除・弱体化されていない
- [ ] デッドコードが残っていない（未使用import、到達不能分岐）
- [ ] チームメイトやレビューエージェントが純改善として承認する
