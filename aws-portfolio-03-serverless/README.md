# Phase 03 — Serverless Gratitude Journal

Status: ✅ Live — https://journal.daoxiao.org/

Docs: [Architecture & design decisions](./docs/Architecture.md) · [Frontend design](./docs/Frontend-Design.md) · [Terraform reference](./infrastructure/terraform/README.md)

## Architecture

```
CloudFront (journal.daoxiao.org) ── S3 (React build)
  │
  ▼  login / signup
Cognito User Pool  ──JWT (ID Token)──┐
                                      ▼
                          API Gateway (HTTP API)
                          JWT Authorizer (backed by Cognito)
                                      │
                    ┌─────────┬───────┼───────┬─────────┐
                POST /entries GET /entries PUT /entries/{id} DELETE /entries/{id}
                    │         │             │             │
              create_entry list_entries update_entry  delete_entry   (Lambda, Python 3.12)
                    └─────────┴───────┬─────┴─────────────┘
                                      ▼
                           DynamoDB (`entries` table)
                           PK: userId / SK: entryId
```

See [`docs/Architecture.md`](./docs/Architecture.md) for the full reasoning
behind every choice below (security model, why single-table design, why HTTP
API, etc.) — this section is just the summary.

## Why this design

- **HTTP API, not REST API**: has a built-in `JWT Authorizer` that natively
  validates Cognito's JWTs. Simpler and cheaper than REST API, and CRUD-scale
  requirements don't need REST API's extra features.
- **Lambda in Python**: the user is learning Python, so the production
  handlers double as learning material.
- **DynamoDB single table, `PK=userId` / `SK=entryId`**: every query is scoped
  to one user's partition — there is no code path that can reach another
  user's data (structural IDOR protection, not a runtime check).
- **Existing IAM user reused (`github-actions-portfolio-01`), no new one
  created**: keeps GitHub Secrets from multiplying with every phase.
- **CI/CD scope is Lambda code only**: infra changes (Cognito/API
  Gateway/DynamoDB/IAM/S3/CloudFront/Route53/ACM) are deployed manually via
  `terraform apply`, same as Phase 2 — the CI IAM user intentionally can't
  create IAM roles, Cognito pools, or CloudFront distributions.
- **S3+CloudFront are Phase 3's own bucket/distribution**, independent of
  Phase 1's — so `terraform destroy` in this phase can never touch Phase 1/2.

## Deploy (first time)

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform
terraform init
terraform plan
terraform apply
```

After `apply`, set the following outputs as the React app's environment
variables (`.env.local`):
- `api_endpoint`
- `cognito_user_pool_id`
- `cognito_user_pool_client_id`

See [`infrastructure/terraform/README.md`](./infrastructure/terraform/README.md)
for the full file-by-file breakdown, all outputs, and gotchas hit while
deploying this phase (IAM permissions, ACM region requirement, DynamoDB
on-demand free tier).

## React frontend

```bash
cd aws-portfolio-03-serverless/frontend
npm install
cp .env.example .env.local   # fill in with the terraform outputs above
npm start                    # local check
```

Production deploy (manual, same command shape as Phase 1):
```bash
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

- **Auth**: talks to Cognito directly via `amazon-cognito-identity-js`
  (sign up → confirm code → sign in → ID token).
- **API calls**: every request carries the ID token in the `Authorization`
  header. A `401` is treated as an expired session and returns the user to
  the login screen.
- **UI parity with Phase 1**: the journal screen mirrors Phase 1's gratitude
  tree, streak counter, tab layout, and ja/en/zh language cycling — see
  [`docs/Frontend-Design.md`](./docs/Frontend-Design.md) for the component
  structure and the non-obvious logic (streak calculation, day-numbering).
- Verified end-to-end by the user in a real browser session (sign up →
  confirm code → sign in → insert/update/delete → sign out), 2026-07-11.

## Remaining work

- [ ] Automated frontend deployment via GitHub Actions (currently manual
      `aws s3 sync` only).

## Folder structure

```
aws-portfolio-03-serverless/
├── docs/
│   ├── Architecture.md        # infra design rationale, security model
│   └── Frontend-Design.md     # React component/auth/state design rationale
├── infrastructure/terraform/
│   ├── README.md              # file-by-file reference, deploy/destroy, gotchas
│   ├── providers.tf
│   ├── variables.tf
│   ├── cognito.tf             # User Pool + App Client
│   ├── dynamodb.tf            # entries table
│   ├── lambda.tf              # execution role + 4 functions
│   ├── api_gateway.tf         # HTTP API + JWT Authorizer + routes
│   ├── iam.tf                 # scoped policy on the existing GitHub Actions user
│   ├── s3_frontend.tf         # frontend hosting bucket
│   ├── cloudfront.tf          # OAC + CloudFront (journal.daoxiao.org)
│   ├── acm.tf                 # ACM certificate (us-east-1)
│   ├── route53.tf             # A record (alias)
│   └── outputs.tf
├── backend/lambda/
│   ├── create_entry/handler.py
│   ├── list_entries/handler.py
│   ├── update_entry/handler.py
│   └── delete_entry/handler.py
└── frontend/
    ├── src/auth/cognito.js       # sign up / confirm / sign in / ID token
    ├── src/api/entries.js        # fetch wrapper for the HTTP API
    ├── src/components/AuthScreen.js
    ├── src/components/JournalScreen.js
    ├── src/components/GratitudeTree.js
    └── src/App.js                # switches screen based on auth state
```

---

# Phase 03 — サーバーレス感謝日記（日本語）

ステータス: ✅ 公開中 — https://journal.daoxiao.org/

ドキュメント: [アーキテクチャ・設計判断](./docs/Architecture.md) ・ [フロントエンド設計](./docs/Frontend-Design.md) ・ [Terraformリファレンス](./infrastructure/terraform/README.md)

## アーキテクチャ

```
CloudFront (journal.daoxiao.org) ── S3（Reactビルド）
  │
  ▼  ログイン / サインアップ
Cognito User Pool  ──JWT (IDトークン)──┐
                                       ▼
                          API Gateway (HTTP API)
                          JWT Authorizer（Cognito連携）
                                       │
                    ┌─────────┬───────┼───────┬─────────┐
                POST /entries GET /entries PUT /entries/{id} DELETE /entries/{id}
                    │         │             │             │
              create_entry list_entries update_entry  delete_entry   (Lambda, Python 3.12)
                    └─────────┴───────┬─────┴─────────────┘
                                      ▼
                           DynamoDB（`entries` テーブル）
                           PK: userId / SK: entryId
```

以下の各設計判断の詳しい理由（セキュリティモデル・シングルテーブル設計の理由・
HTTP APIを選んだ理由など）は[`docs/Architecture.md`](./docs/Architecture.md)を
参照。ここには要約のみ記載する。

## なぜこの設計か

- **HTTP API（REST APIではなく）**: CognitoのJWTをネイティブ検証できる
  `JWT Authorizer`を標準搭載。REST APIより設定がシンプルで低コスト。
  CRUD程度の要件にはREST APIの追加機能は不要。
- **Lambda言語をPython**: ユーザーがPython学習中のため、実務コードがそのまま
  学習教材になる。
- **DynamoDBシングルテーブル + PK=userId/SK=entryId**: すべてのQueryが
  1ユーザーのパーティションに閉じており、他ユーザーのデータへ到達する
  コード経路自体が存在しない（実行時チェックではなく構造的なIDOR対策）。
- **既存IAMユーザー(github-actions-portfolio-01)を再利用**: 新規作成せず、
  Phase毎にGitHub Secretsが増殖しないようにする。
- **CI/CDのスコープはLambdaコード更新のみ**: インフラ変更（Cognito/API
  Gateway/DynamoDB/IAM/S3/CloudFront/Route53/ACM）はPhase 2と同様、
  ローカルから`terraform apply`で手動デプロイする。CI用IAMユーザーには
  意図的にIAMロール・Cognitoプール・CloudFrontディストリビューションの
  作成権限を持たせていない。
- **S3+CloudFrontはPhase 3専用のバケット・ディストリビューション**:
  Phase 1とは完全に独立しており、このPhaseの`terraform destroy`が
  Phase 1・Phase 2に影響することはない。

## デプロイ手順（初回）

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform
terraform init
terraform plan
terraform apply
```

apply完了後、以下のoutputsをReactアプリの環境変数（`.env.local`）に設定する：
- `api_endpoint`
- `cognito_user_pool_id`
- `cognito_user_pool_client_id`

ファイルごとの詳細・全outputs・このPhaseのデプロイで実際に遭遇した注意点
（IAM権限・ACMのリージョン制約・DynamoDBオンデマンドの無料枠）は
[`infrastructure/terraform/README.md`](./infrastructure/terraform/README.md)を参照。

## React フロントエンド

```bash
cd aws-portfolio-03-serverless/frontend
npm install
cp .env.example .env.local   # 上記のterraform outputsの値を書き込む
npm start                    # ローカル確認
```

本番デプロイ（手動・Phase 1と同じコマンド体系）:
```bash
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

- **認証**: `amazon-cognito-identity-js`でCognitoと直接通信
  （サインアップ→確認コード→ログイン→IDトークン取得）。
- **API呼び出し**: 全リクエストのAuthorizationヘッダーにIDトークンを付与。
  401が返るとセッション切れとみなしログイン画面へ戻す。
- **Phase 1とのUI統一**: 日記画面はPhase 1の感謝の木・連続日数カウンター・
  タブレイアウト・日英中の言語切替を踏襲している。コンポーネント構成や
  非自明なロジック（連続日数の計算・日数バッジ）の詳細は
  [`docs/Frontend-Design.md`](./docs/Frontend-Design.md)を参照。
- ユーザーが実際のブラウザでサインアップ→確認コード→ログイン→
  insert/update/delete→ログアウトを実施し、動作を確認済み（2026-07-11）。

## 残タスク

- [ ] GitHub Actionsでのフロントエンド自動デプロイ（現状は手動
      `aws s3 sync`のみ）

## フォルダ構成

```
aws-portfolio-03-serverless/
├── docs/
│   ├── Architecture.md        # インフラ設計の理由・セキュリティモデル
│   └── Frontend-Design.md     # Reactのコンポーネント/認証/状態設計の理由
├── infrastructure/terraform/
│   ├── README.md              # ファイル別リファレンス・デプロイ/削除・注意点
│   ├── providers.tf
│   ├── variables.tf
│   ├── cognito.tf             # User Pool + App Client
│   ├── dynamodb.tf            # entries テーブル
│   ├── lambda.tf              # 実行ロール + 4関数
│   ├── api_gateway.tf         # HTTP API + JWT Authorizer + ルート
│   ├── iam.tf                 # 既存GitHub Actionsユーザーへの限定ポリシー
│   ├── s3_frontend.tf         # フロントエンド配信用バケット
│   ├── cloudfront.tf          # OAC + CloudFront（journal.daoxiao.org）
│   ├── acm.tf                 # ACM証明書（us-east-1）
│   ├── route53.tf             # Aレコード(alias)
│   └── outputs.tf
├── backend/lambda/
│   ├── create_entry/handler.py
│   ├── list_entries/handler.py
│   ├── update_entry/handler.py
│   └── delete_entry/handler.py
└── frontend/
    ├── src/auth/cognito.js       # サインアップ/確認/ログイン/IDトークン取得
    ├── src/api/entries.js        # HTTP APIへのfetchラッパー
    ├── src/components/AuthScreen.js
    ├── src/components/JournalScreen.js
    ├── src/components/GratitudeTree.js
    └── src/App.js                # 認証状態で画面切替
```
