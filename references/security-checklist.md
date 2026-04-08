# セキュリティチェックリスト

Web アプリケーションセキュリティのクイックリファレンス。`security-and-hardening` スキルと併用してください。

## 目次

- [コミット前チェック](#コミット前チェック)
- [認証](#認証)
- [認可](#認可)
- [入力検証](#入力検証)
- [セキュリティヘッダ](#セキュリティヘッダ)
- [CORS 設定](#cors-設定)
- [データ保護](#データ保護)
- [依存関係セキュリティ](#依存関係セキュリティ)
- [エラーハンドリング](#エラーハンドリング)
- [OWASP Top 10 クイックリファレンス](#owasp-top-10-クイックリファレンス)

## コミット前チェック

- [ ] コード内にシークレットなし（`git diff --cached | grep -i "password\|secret\|api_key\|token"`）
- [ ] `.gitignore` に以下を含む: `.env`、`.env.local`、`*.pem`、`*.key`
- [ ] `.env.example` はプレースホルダ値（実シークレットではない）

## 認証

- [ ] パスワードは bcrypt（≥12 ラウンド）、scrypt、または argon2 でハッシュ化
- [ ] セッションクッキー: `httpOnly`、`secure`、`sameSite: 'lax'`
- [ ] セッション有効期限を設定（妥当な max-age）
- [ ] ログインエンドポイントにレート制限（15 分あたり ≤10 試行）
- [ ] パスワードリセットトークン: 時間制限（≤1 時間）、単回使用
- [ ] 連続失敗でアカウントロック（任意、通知付き）
- [ ] 機密操作に MFA 対応（任意だが推奨）

## 認可

- [ ] すべての保護エンドポイントで認証を確認
- [ ] すべてのリソースアクセスで所有権/ロールを確認（IDOR 防止）
- [ ] 管理者エンドポイントは管理者ロール検証を要求
- [ ] API キーは必要最小限の権限にスコープ
- [ ] JWT トークンを検証（署名、有効期限、発行者）

## 入力検証

- [ ] すべてのユーザー入力をシステム境界で検証（API ルート、フォームハンドラ）
- [ ] 検証は許可リストを使用（拒否リストではない）
- [ ] 文字列長を制約（最小/最大）
- [ ] 数値範囲を検証
- [ ] Email、URL、日付形式を適切なライブラリで検証
- [ ] ファイルアップロード: 種類制限、サイズ制限、内容検証
- [ ] SQL クエリのパラメータ化（文字列連結禁止）
- [ ] HTML 出力のエンコード（フレームワークの自動エスケープを使用）
- [ ] リダイレクト前に URL を検証（オープンリダイレクト防止）

## セキュリティヘッダ

```
Content-Security-Policy: default-src 'self'; script-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0  (disabled, rely on CSP)
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

## CORS 設定

```typescript
// 制限的（推奨）
cors({
  origin: ['https://yourdomain.com', 'https://app.yourdomain.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

// 本番では絶対に使わない:
cors({ origin: '*' })  // 任意のオリジンを許可
```

## データ保護

- [ ] 機密フィールドを API レスポンスから除外（`passwordHash`、`resetToken` など）
- [ ] 機密データをログに記録しない（パスワード、トークン、完全な CC 番号）
- [ ] PII を保存時に暗号化（規制要求時）
- [ ] すべての外部通信に HTTPS
- [ ] データベースバックアップを暗号化

## 依存関係セキュリティ

```bash
# 依存関係の監査
npm audit

# 可能な範囲で自動修正
npm audit fix

# クリティカル脆弱性の確認
npm audit --audit-level=critical

# 依存関係を最新に
npx npm-check-updates
```

## エラーハンドリング

```typescript
// 本番: 汎用エラー、内部情報なし
res.status(500).json({
  error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' }
});

// 本番で絶対にやらない:
res.status(500).json({
  error: err.message,
  stack: err.stack,         // 内部を露出
  query: err.sql,           // DB 詳細を露出
});
```

## OWASP Top 10 クイックリファレンス

| # | 脆弱性 | 予防策 |
|---|---|---|
| 1 | アクセス制御の不備 | 全エンドポイントで認可確認、所有権検証 |
| 2 | 暗号化の失敗 | HTTPS、強力なハッシュ、コードにシークレットなし |
| 3 | インジェクション | パラメータ化クエリ、入力検証 |
| 4 | 安全でない設計 | 脅威モデリング、spec 駆動開発 |
| 5 | セキュリティ設定ミス | セキュリティヘッダ、最小権限、依存監査 |
| 6 | 脆弱なコンポーネント | `npm audit`、依存更新、依存最小化 |
| 7 | 認証の失敗 | 強いパスワード、レート制限、セッション管理 |
| 8 | データ整合性の失敗 | 更新/依存の検証、署名済みアーティファクト |
| 9 | ロギングの失敗 | セキュリティイベントのログ、シークレット非ログ |
| 10 | SSRF | URL 検証/許可リスト、外向き通信制限 |
