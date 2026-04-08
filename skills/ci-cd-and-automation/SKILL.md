---
name: ci-cd-and-automation
description: Automates CI/CD pipeline setup. Use when setting up or modifying build and deployment pipelines. Use when you need to automate quality gates, configure test runners in CI, or establish deployment strategies.
---

# CI/CDと自動化

## 概要

品質ゲートを自動化し、テスト、lint、型チェック、ビルドを通らずに変更が本番に到達しないようにする。CI/CDは他のすべてのスキルの強制メカニズム――人間とエージェントが見逃すものを捕え、すべての変更で一貫して行う。

**Shift Left:** 問題をパイプラインのできるだけ早い段階で捕える。lintで捕えるバグは数分のコスト、本番で捕える同じバグは数時間のコスト。チェックを上流に移す――テストの前に静的解析、ステージングの前にテスト、本番の前にステージング。

**速い方が安全:** 小さなバッチとより頻繁なリリースはリスクを下げる、上げるのではない。3変更のデプロイは30変更より簡単にデバッグできる。頻繁なリリースはリリースプロセス自体への信頼を築く。

## 使うとき

- 新プロジェクトのCIパイプラインをセットアップ
- 自動チェックを追加・変更
- デプロイパイプラインを設定
- 変更が自動検証をトリガーするべきとき
- CI失敗をデバッグ

## 品質ゲートパイプライン

すべての変更はマージ前に次のゲートを通る:

```
プルリクエストオープン
    │
    ▼
┌─────────────────┐
│   LINTチェック    │  eslint, prettier
│   ↓ 通過         │
│   型チェック      │  tsc --noEmit
│   ↓ 通過         │
│   ユニットテスト   │  jest/vitest
│   ↓ 通過         │
│   ビルド         │  npm run build
│   ↓ 通過         │
│   統合テスト      │  API/DBテスト
│   ↓ 通過         │
│   E2E（任意）    │  Playwright/Cypress
│   ↓ 通過         │
│   セキュリティ監査 │  npm audit
│   ↓ 通過         │
│   バンドルサイズ  │  bundlesize check
└─────────────────┘
    │
    ▼
  レビュー準備完了
```

**どのゲートもスキップできない。** lintが失敗したらlintを直す――ルールを無効化しない。テストが失敗したらコードを直す――テストをスキップしない。

## GitHub Actions 設定

### 基本CIパイプライン

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Type check
        run: npx tsc --noEmit

      - name: Test
        run: npm test -- --coverage

      - name: Build
        run: npm run build

      - name: Security audit
        run: npm audit --audit-level=high
```

### DB統合テスト付き

```yaml
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: ci_user
          POSTGRES_PASSWORD: ${{ secrets.CI_DB_PASSWORD }}
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - name: Run migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://ci_user:${{ secrets.CI_DB_PASSWORD }}@localhost:5432/testdb
      - name: Integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://ci_user:${{ secrets.CI_DB_PASSWORD }}@localhost:5432/testdb
```

> **注意:** CI専用のテストDBでも、値をハードコードせずGitHub Secretsで資格情報を使う。良い習慣を築き、テスト資格情報の偶発的再利用を防ぐ。

### E2Eテスト

```yaml
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - name: Install Playwright
        run: npx playwright install --with-deps chromium
      - name: Build
        run: npm run build
      - name: Run E2E tests
        run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

## CI失敗をエージェントにフィードバック

AIエージェントとのCIの力はフィードバックループにある。CIが失敗したら:

```
CI失敗
    │
    ▼
失敗出力をコピー
    │
    ▼
エージェントに食わせる:
「CIパイプラインが次のエラーで失敗した:
[具体エラーを貼付]
問題を修正し、再プッシュ前にローカルで検証して。」
    │
    ▼
エージェントが修正 → プッシュ → CI再実行
```

**主要パターン:**

```
Lint失敗 → エージェントが `npm run lint --fix` を実行してコミット
型エラー → エージェントがエラー位置を読んで型を修正
テスト失敗 → エージェントがdebugging-and-error-recoveryスキルに従う
ビルドエラー → エージェントが設定と依存をチェック
```

## デプロイ戦略

### プレビューデプロイ

すべてのPRに手動テスト用のプレビューデプロイ:

```yaml
# PRでプレビューデプロイ（Vercel/Netlify等）
deploy-preview:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v4
    - name: Deploy preview
      run: npx vercel --token=${{ secrets.VERCEL_TOKEN }}
```

### フィーチャーフラグ

フィーチャーフラグはデプロイとリリースを分離する。未完成や危険な機能をフラグ裏にデプロイすれば:

- **有効化せずコードを出荷。** 早期にmainにマージ、準備できたら有効化。
- **再デプロイなしでロールバック。** コードをリバートする代わりにフラグを無効化。
- **新機能のカナリア。** ユーザーの1%、次に10%、次に100%で有効化。
- **A/Bテスト。** 機能ありなしの挙動を比較。

```typescript
// シンプルなフィーチャーフラグパターン
if (featureFlags.isEnabled('new-checkout-flow', { userId })) {
  return renderNewCheckout();
}
return renderLegacyCheckout();
```

**フラグのライフサイクル:** 作成 → テスト用有効化 → カナリア → 完全ロールアウト → フラグとデッドコード削除。永遠に生きるフラグは技術的負債になる――作成時にクリーンアップ日を設定する。

### 段階的ロールアウト

```
PRがmainにマージ
    │
    ▼
  ステージングデプロイ（自動）
    │ 手動検証
    ▼
  本番デプロイ（手動トリガー、またはステージング後自動）
    │
    ▼
  エラー監視（15分ウィンドウ）
    │
    ├── エラー検出 → ロールバック
    └── クリーン → 完了
```

### ロールバック計画

すべてのデプロイは可逆であるべき:

```yaml
# 手動ロールバックワークフロー
name: Rollback
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Rollback deployment
        run: |
          # 指定された以前のバージョンをデプロイ
          npx vercel rollback ${{ inputs.version }}
```

## 環境管理

```
.env.example       → コミット（開発者向けテンプレート）
.env                → コミットしない（ローカル開発）
.env.test           → コミット（テスト環境、実シークレットなし）
CIシークレット      → GitHub Secrets / vault に保存
本番シークレット    → デプロイプラットフォーム / vault に保存
```

CIは本番シークレットを持たない。CIテスト用に別シークレットを使う。

## CI以外の自動化

### Dependabot / Renovate

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
```

### Build Cop ロール

CIを緑に保つ責任者を指名。ビルドが壊れたら、Build Copの仕事は修正またはリバート――変更を引き起こした人ではない。これで全員が「誰かが直すだろう」と思って壊れたビルドが蓄積するのを防ぐ。

### PRチェック

- **必須レビュー:** マージ前に最低1承認
- **必須ステータスチェック:** マージ前にCIが通ること
- **ブランチ保護:** mainへのforce push禁止
- **オートマージ:** すべてのチェックが通り承認されたら自動マージ

## CI最適化

パイプラインが10分を超えたら、効果順にこれらの戦略を適用:

```
遅いCIパイプライン?
├── 依存をキャッシュ
│   └── actions/cache または setup-node の cache オプションを node_modules に使用
├── ジョブを並行実行
│   └── lint、typecheck、test、buildを別ジョブに分割
├── 変更のあるものだけ実行
│   └── パスフィルタで無関係ジョブをスキップ（例: docsのみPRでe2eスキップ）
├── マトリックスビルド使用
│   └── テストスイートを複数ランナーに分散
├── テストスイートを最適化
│   └── 遅いテストをクリティカルパスから外し、スケジュール実行
└── より大きなランナーを使用
    └── GitHubホスト大型ランナーまたはCPU重ビルド向け自己ホスト
```

**例: キャッシュと並行性**
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npx tsc --noEmit

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm test -- --coverage
```

## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| 「CIが遅すぎる」 | パイプラインを最適化（下のCI最適化参照）、スキップしない。5分のパイプラインが数時間のデバッグを防ぐ。 |
| 「この変更は些細、CIスキップ」 | 些細な変更がビルドを壊す。些細ならCIも速い。 |
| 「テストがflakyだから再実行」 | flakyテストは実バグを隠し全員の時間を無駄にする。flakyを直せ。 |
| 「CIは後で追加」 | CIのないプロジェクトは壊れた状態を蓄積する。初日にセットアップ。 |
| 「手動テストで十分」 | 手動テストはスケールせず再現可能でない。できるところは自動化。 |

## レッドフラグ

- プロジェクトにCIパイプラインなし
- CI失敗が無視・沈黙される
- パイプラインを通すためにCIでテストを無効化
- ステージング検証なしの本番デプロイ
- ロールバック機構なし
- コードやCI設定ファイル（シークレットマネージャ外）にシークレット
- 最適化努力のない長いCI時間

## 検証

CIセットアップ/変更後:

- [ ] すべての品質ゲートが存在（lint、型、テスト、ビルド、監査）
- [ ] パイプラインがすべてのPRとmainプッシュで動く
- [ ] 失敗がマージをブロック（ブランチ保護設定）
- [ ] CI結果が開発ループにフィードバックされる
- [ ] シークレットがシークレットマネージャに保存される（コード内ではなく）
- [ ] デプロイにロールバック機構がある
- [ ] パイプラインがテストスイートで10分未満
