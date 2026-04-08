---
name: documentation-and-adrs
description: Records decisions and documentation. Use when making architectural decisions, changing public APIs, shipping features, or when you need to record context that future engineers and agents will need to understand the codebase.
---

# ドキュメントとADR

## 概要

コードではなく決定を文書化する。最も価値あるドキュメントは *なぜ* を捕える――決定に至ったコンテキスト、制約、トレードオフ。コードは *何が* 作られたかを示す。ドキュメントは *なぜこう作られたか* と *どんな代替が検討されたか* を説明する。このコンテキストはコードベースで働く将来の人間とエージェントに必須。

## 使うとき

- 重要なアーキテクチャ決定をするとき
- 競合するアプローチから選ぶとき
- パブリックAPIを追加・変更するとき
- ユーザー向け挙動を変える機能を出荷するとき
- 新チームメンバー（またはエージェント）をプロジェクトにオンボーディング
- 同じことを繰り返し説明している自分に気づいたとき

**使わないとき:** 自明なコードを文書化しない。コードが既に述べていることを繰り返すコメントを追加しない。使い捨てプロトタイプに文書を書かない。

## Architecture Decision Records (ADRs)

ADRは重要な技術決定の背後にある理由を捕える。書ける中で最も価値の高いドキュメント。

### ADRを書くとき

- フレームワーク、ライブラリ、主要依存の選択
- データモデルやDBスキーマの設計
- 認証戦略の選択
- APIアーキテクチャの決定（REST vs GraphQL vs tRPC）
- ビルドツール、ホスティング、インフラの選択
- 逆転コストが高い任意の決定

### ADRテンプレート

ADRを `docs/decisions/` に連番で保存:

```markdown
# ADR-001: 主データベースに PostgreSQL を採用

## ステータス
承認済み | ADR-XXX により置き換え | 廃止

## 日付
2025-01-15

## 背景
タスク管理アプリケーションの主データベースが必要。主な要件:
- リレーショナルデータモデル（ユーザー、タスク、チームとその関係）
- タスク状態変更のための ACID トランザクション
- タスク内容に対する全文検索のサポート
- マネージドホスティングが利用可能（小規模チーム・運用体制が限定的）

## 決定
Prisma ORM と組み合わせて PostgreSQL を使う。

## 検討した代替案

### MongoDB
- 利点: スキーマが柔軟で始めやすい
- 欠点: 我々のデータは本質的にリレーショナル。関係を手動管理する必要が出る
- 却下理由: ドキュメントストアでリレーショナルデータを扱うと、複雑な join かデータ重複につながる

### SQLite
- 利点: 設定不要、組み込み、読み込みが速い
- 欠点: 並列書き込みサポートが限定的、本番向けマネージドホスティングなし
- 却下理由: 本番のマルチユーザー Web アプリには不向き

### MySQL
- 利点: 成熟していて広くサポートされている
- 欠点: PostgreSQL の方が JSON サポート、全文検索、エコシステムツールで優れる
- 却下理由: 我々の機能要件には PostgreSQL の方が合う

## 帰結
- Prisma が型安全なDBアクセスとマイグレーション管理を提供
- Elasticsearch を追加する代わりに PostgreSQL の全文検索が使える
- チームに PostgreSQL の知識が必要（標準スキル、リスク低）
- マネージドサービス（Supabase、Neon、RDS）でホスティング
```

### ADRライフサイクル

```
PROPOSED → ACCEPTED → (SUPERSEDED or DEPRECATED)
```

- **古いADRを削除しない。** 歴史的コンテキストを捕える。
- 決定が変わったら、古いものを参照して置き換える新ADRを書く。

## インラインドキュメント

### コメントをするとき

*何* ではなく *なぜ* をコメント:

```typescript
// 悪: コードを繰り返す
// カウンタを1増やす
counter += 1;

// 良: 非自明な意図を説明
// レートリミットはスライディングウィンドウを使う――ウィンドウ境界でリセット、
// 固定スケジュールではなく、ウィンドウエッジでのバースト攻撃を防ぐため
if (now - windowStart > WINDOW_SIZE_MS) {
  counter = 0;
  windowStart = now;
}
```

### コメントしないとき

```typescript
// 自己説明的なコードにコメントしない
function calculateTotal(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

// 今やるべきことにTODOコメントを残さない
// TODO: エラーハンドリング追加  ← 今追加せよ

// コメントアウトコードを残さない
// const oldImplementation = () => { ... }  ← 削除せよ、gitに履歴がある
```

### 既知の罠を文書化

```typescript
/**
 * 重要: この関数は初回レンダリング前に呼ぶ必要がある。
 * ハイドレーション後に呼ぶと、SSR 中にテーマコンテキストが
 * 利用できないためスタイル未適用のコンテンツがちらつく。
 *
 * 詳細な設計理由は ADR-003 を参照。
 */
export function initializeTheme(theme: Theme): void {
  // ...
}
```

## APIドキュメント

パブリックAPI（REST、GraphQL、ライブラリインターフェース）について:

### 型と一緒にインライン（TypeScript推奨）

```typescript
/**
 * 新しいタスクを作成する。
 *
 * @param input - タスク作成データ（title は必須、description は任意）
 * @returns サーバー生成の ID とタイムスタンプを持つ作成済みタスク
 * @throws {ValidationError} title が空または 200 文字を超える場合
 * @throws {AuthenticationError} ユーザーが認証されていない場合
 *
 * @example
 * const task = await createTask({ title: 'Buy groceries' });
 * console.log(task.id); // "task_abc123"
 */
export async function createTask(input: CreateTaskInput): Promise<Task> {
  // ...
}
```

### REST APIのOpenAPI / Swagger

```yaml
paths:
  /api/tasks:
    post:
      summary: タスクを作成する
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateTaskInput'
      responses:
        '201':
          description: タスクが作成された
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        '422':
          description: バリデーションエラー
```

## README構造

すべてのプロジェクトは次をカバーするREADMEを持つべき:

```markdown
# プロジェクト名

このプロジェクトが何をするかを1段落で説明。

## クイックスタート
1. リポジトリをクローン
2. 依存関係をインストール: `npm install`
3. 環境をセットアップ: `cp .env.example .env`
4. 開発サーバーを起動: `npm run dev`

## コマンド
| コマンド | 説明 |
|---------|-------------|
| `npm run dev` | 開発サーバーを起動 |
| `npm test` | テストを実行 |
| `npm run build` | 本番ビルド |
| `npm run lint` | リンターを実行 |

## アーキテクチャ
プロジェクト構造と主要な設計決定の概要。
詳細は ADR へのリンクを参照。

## コントリビュート
コントリビュート方法、コーディング規約、PR プロセス。
```

## Changelog維持

出荷された機能について:

```markdown
# 変更履歴

## [1.2.0] - 2025-01-20
### 追加
- タスク共有: ユーザーがチームメンバーとタスクを共有できる (#123)
- タスク割り当て時のメール通知 (#124)

### 修正
- 作成ボタンの連打時に重複タスクが出る不具合 (#125)

### 変更
- UX 改善のため、タスクリストを 1 ページあたり 50 件読み込むようにした（以前は 20 件）(#126)
```

## エージェント向けドキュメント

AIエージェントコンテキストへの特別配慮:

- **CLAUDE.md / ルールファイル** ――エージェントが従うようプロジェクト慣習を文書化
- **仕様ファイル** ――エージェントが正しいものを作るよう仕様を最新に保つ
- **ADR** ――過去の決定の理由をエージェントに理解させる（再決定防止）
- **インラインの罠** ――エージェントが既知の罠にはまるのを防ぐ

## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| 「コードが自己文書化してる」 | コードは何を示す。なぜ、何が却下されたか、何の制約が適用されるかは示さない。 |
| 「APIが安定したらドキュメント書く」 | APIは文書化する方が速く安定する。ドキュメントは設計の最初のテスト。 |
| 「誰もドキュメント読まない」 | エージェントは読む。将来のエンジニアも。3ヶ月後の自分も。 |
| 「ADRはオーバーヘッド」 | 10分のADRが6ヶ月後の2時間の同じ決定についての議論を防ぐ。 |
| 「コメントは古くなる」 | *なぜ* についてのコメントは安定。 *何* についてのコメントは古くなる――だから後者しか書かない。 |

## レッドフラグ

- 書かれた理由のないアーキテクチャ決定
- ドキュメントや型のないパブリックAPI
- プロジェクトの実行方法を説明しないREADME
- 削除の代わりにコメントアウトコード
- 何週間も残るTODOコメント
- 重要なアーキテクチャ選択のあるプロジェクトにADRなし
- 意図を説明せずコードを繰り返すドキュメント

## 検証

ドキュメント後:

- [ ] 重要なアーキテクチャ決定にADRが存在
- [ ] READMEがクイックスタート、コマンド、アーキテクチャ概要をカバー
- [ ] API関数にパラメータと戻り型のドキュメント
- [ ] 既知の罠が影響ある箇所でインライン文書化
- [ ] コメントアウトコードが残っていない
- [ ] ルールファイル（CLAUDE.md等）が最新で正確
