---
name: security-and-hardening
description: Hardens code against vulnerabilities. Use when handling user input, authentication, data storage, or external integrations. Use when building any feature that accepts untrusted data, manages user sessions, or interacts with third-party services.
---

# セキュリティとハードニング

## 概要

Webアプリケーションのセキュリティファースト開発実践。すべての外部入力を敵対的、すべてのシークレットを神聖、すべての認可チェックを必須として扱う。セキュリティはフェーズではない――ユーザーデータ、認証、外部システムに触れるすべての行への制約。

## 使うとき

- ユーザー入力を受け付けるものを構築するとき
- 認証・認可を実装するとき
- 機密データを保存・送信するとき
- 外部APIやサービスと統合するとき
- ファイルアップロード、webhook、コールバックを追加するとき
- 決済やPIIデータを扱うとき

## 3段階境界システム

### 常に行う（例外なし）

- **すべての外部入力を境界で検証**（APIルート、フォームハンドラ）
- **すべてのDBクエリをパラメータ化** ――ユーザー入力をSQLに連結しない
- **出力をエンコード**してXSSを防ぐ（フレームワークの自動エスケープ使用、バイパスしない）
- **すべての外部通信にHTTPSを使う**
- **パスワードをbcrypt/scrypt/argon2でハッシュ**（平文保存禁止）
- **セキュリティヘッダーを設定**（CSP、HSTS、X-Frame-Options、X-Content-Type-Options）
- **セッションにhttpOnly、secure、sameSite cookieを使う**
- リリース前に **`npm audit`** （または同等）を実行

### まず尋ねる（人間の承認が必要）

- 新しい認証フローの追加や認証ロジック変更
- 新しいカテゴリの機密データ（PII、決済情報）の保存
- 新しい外部サービス統合の追加
- CORS設定の変更
- ファイルアップロードハンドラの追加
- レートリミットやスロットリングの変更
- 昇格権限やロールの付与

### 決して行わない

- **シークレットをバージョン管理にコミットしない**（APIキー、パスワード、トークン）
- **機密データをログしない**（パスワード、トークン、完全なクレジットカード番号）
- **クライアント側検証をセキュリティ境界として信用しない**
- **便宜のためにセキュリティヘッダーを無効化しない**
- **`eval()` や `innerHTML` をユーザー提供データで使わない**
- **セッションをクライアントアクセス可能なストレージに保存しない**（認証トークンのlocalStorage）
- **スタックトレースや内部エラー詳細をユーザーに露出しない**

## OWASP Top 10 対策

### 1. インジェクション（SQL、NoSQL、OSコマンド）

```typescript
// 悪: 文字列連結によるSQLインジェクション
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// 良: パラメータ化クエリ
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

// 良: パラメータ化入力を持つORM
const user = await prisma.user.findUnique({ where: { id: userId } });
```

### 2. 認証の破損

```typescript
// パスワードハッシュ
import { hash, compare } from 'bcrypt';

const SALT_ROUNDS = 12;
const hashedPassword = await hash(plaintext, SALT_ROUNDS);
const isValid = await compare(plaintext, hashedPassword);

// セッション管理
app.use(session({
  secret: process.env.SESSION_SECRET,  // 環境変数から、コードに書かない
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,     // JavaScriptからアクセス不可
    secure: true,       // HTTPSのみ
    sameSite: 'lax',    // CSRF対策
    maxAge: 24 * 60 * 60 * 1000,  // 24時間
  },
}));
```

### 3. クロスサイトスクリプティング（XSS）

```typescript
// 悪: ユーザー入力をHTMLとしてレンダー
element.innerHTML = userInput;

// 良: フレームワークの自動エスケープを使う（Reactはデフォルトで行う）
return <div>{userInput}</div>;

// HTMLをレンダーする必要があるなら先にサニタイズ
import DOMPurify from 'dompurify';
const clean = DOMPurify.sanitize(userInput);
```

### 4. アクセス制御の破損

```typescript
// 認証だけでなく認可を常にチェック
app.patch('/api/tasks/:id', authenticate, async (req, res) => {
  const task = await taskService.findById(req.params.id);

  // 認証されたユーザーがこのリソースを所有するか確認
  if (task.ownerId !== req.user.id) {
    return res.status(403).json({
      error: { code: 'FORBIDDEN', message: 'Not authorized to modify this task' }
    });
  }

  // 更新に進む
  const updated = await taskService.update(req.params.id, req.body);
  return res.json(updated);
});
```

### 5. セキュリティ設定ミス

```typescript
// セキュリティヘッダー（Expressならhelmetを使う）
import helmet from 'helmet';
app.use(helmet());

// Content Security Policy
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],  // 可能なら厳しく
    imgSrc: ["'self'", 'data:', 'https:'],
    connectSrc: ["'self'"],
  },
}));

// CORS ――既知のoriginに制限
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true,
}));
```

### 6. 機密データの露出

```typescript
// APIレスポンスで機密フィールドを返さない
function sanitizeUser(user: UserRecord): PublicUser {
  const { passwordHash, resetToken, ...publicFields } = user;
  return publicFields;
}

// シークレットには環境変数を使う
const API_KEY = process.env.STRIPE_API_KEY;
if (!API_KEY) throw new Error('STRIPE_API_KEY not configured');
```

## 入力検証パターン

### 境界でのスキーマ検証

```typescript
import { z } from 'zod';

const CreateTaskSchema = z.object({
  title: z.string().min(1).max(200).trim(),
  description: z.string().max(2000).optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  dueDate: z.string().datetime().optional(),
});

// ルートハンドラで検証
app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid input',
        details: result.error.flatten(),
      },
    });
  }
  // result.dataは型付けされ検証済み
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

### ファイルアップロード安全性

```typescript
// ファイルタイプとサイズを制限
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

function validateUpload(file: UploadedFile) {
  if (!ALLOWED_TYPES.includes(file.mimetype)) {
    throw new ValidationError('File type not allowed');
  }
  if (file.size > MAX_SIZE) {
    throw new ValidationError('File too large (max 5MB)');
  }
  // ファイル拡張子を信用しない――クリティカルならmagic bytesをチェック
}
```

## npm audit 結果のトリアージ

すべての監査結果が即時対応を要するわけではない。この決定木を使う:

```
npm audit が脆弱性を報告
├── 重大度: critical または high
│   ├── 脆弱なコードがアプリから到達可能か?
│   │   ├── YES --> 即時修正（更新、パッチ、依存置換）
│   │   └── NO（開発のみ依存、未使用パス） --> 早めに修正、ブロッカーではない
│   └── 修正は利用可能か?
│       ├── YES --> パッチ済み版に更新
│       └── NO --> 回避策を探す、依存置換を検討、またはレビュー日付付きでallowlistに追加
├── 重大度: moderate
│   ├── 本番で到達可能? --> 次のリリースサイクルで修正
│   └── 開発のみ? --> 都合のよいときに修正、バックログで追跡
└── 重大度: low
    └── 通常の依存更新中に追跡・修正
```

**重要な質問:**
- 脆弱な関数は実際にコードパスで呼ばれているか?
- 依存はランタイム依存か開発のみか?
- デプロイコンテキストで脆弱性は悪用可能か?（例: クライアントのみのアプリでのサーバー側脆弱性）

修正を延期する場合、理由を記録しレビュー日を設定する。

## レートリミット

```typescript
import rateLimit from 'express-rate-limit';

// 一般API レートリミット
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100,                   // ウィンドウあたり100リクエスト
  standardHeaders: true,
  legacyHeaders: false,
}));

// 認証エンドポイントにはより厳しく
app.use('/api/auth/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,  // 15分で10試行
}));
```

## シークレット管理

```
.env ファイル:
  ├── .env.example  → コミットする（プレースホルダ値のテンプレート）
  ├── .env          → コミットしない（実シークレット）
  └── .env.local    → コミットしない（ローカル上書き）

.gitignore は以下を含むこと:
  .env
  .env.local
  .env.*.local
  *.pem
  *.key
```

**コミット前に必ずチェック:**
```bash
# 誤ってステージされたシークレットをチェック
git diff --cached | grep -i "password\|secret\|api_key\|token"
```

## セキュリティレビューチェックリスト

```markdown
### 認証
- [ ] パスワードがbcrypt/scrypt/argon2でハッシュ（salt rounds ≥ 12）
- [ ] セッショントークンがhttpOnly、secure、sameSite
- [ ] ログインにレートリミット
- [ ] パスワードリセットトークンが期限切れ

### 認可
- [ ] すべてのエンドポイントがユーザー権限をチェック
- [ ] ユーザーは自分のリソースのみアクセス可能
- [ ] 管理アクションに管理ロール検証

### 入力
- [ ] すべてのユーザー入力が境界で検証
- [ ] SQLクエリがパラメータ化
- [ ] HTML出力がエンコード・エスケープ

### データ
- [ ] コードやバージョン管理にシークレットなし
- [ ] APIレスポンスから機密フィールド除外
- [ ] PIIが保存時に暗号化（該当時）

### インフラ
- [ ] セキュリティヘッダー設定（CSP、HSTS等）
- [ ] CORSが既知のオリジンに制限
- [ ] 依存の脆弱性監査済み
- [ ] エラーメッセージが内部を露出しない
```
## 関連

詳細なセキュリティチェックリストとコミット前検証ステップは `references/security-checklist.md` を参照。

## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| 「内部ツールだからセキュリティは関係ない」 | 内部ツールも侵害される。攻撃者は最弱点を狙う。 |
| 「セキュリティは後で追加する」 | セキュリティの後付けは最初から組み込むより10倍大変。今加えろ。 |
| 「これを悪用する人はいない」 | 自動スキャナが見つける。難読化によるセキュリティはセキュリティではない。 |
| 「フレームワークがセキュリティを処理する」 | フレームワークはツールを提供するが保証はしない。正しく使う必要がある。 |
| 「ただのプロトタイプ」 | プロトタイプは本番になる。初日からセキュリティ習慣を。 |

## レッドフラグ

- ユーザー入力が直接DBクエリ、シェルコマンド、HTMLレンダリングに渡される
- ソースコードやコミット履歴にシークレット
- 認証・認可チェックなしのAPIエンドポイント
- CORS設定欠如またはワイルドカード（`*`）オリジン
- 認証エンドポイントにレートリミットなし
- スタックトレースや内部エラーがユーザーに露出
- 既知のcritical脆弱性を持つ依存

## 検証

セキュリティ関連コード実装後:

- [ ] `npm audit` が critical/high 脆弱性ゼロを示す
- [ ] ソースコードやgit履歴にシークレットなし
- [ ] すべてのユーザー入力がシステム境界で検証
- [ ] すべての保護エンドポイントで認証・認可をチェック
- [ ] レスポンスにセキュリティヘッダーが存在（ブラウザDevToolsでチェック）
- [ ] エラーレスポンスが内部詳細を露出しない
- [ ] 認証エンドポイントでレートリミットが有効
