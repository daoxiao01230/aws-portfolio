# Phase 03 — Serverless Gratitude Journal

Status: ✅ Live — https://journal.daoxiao.org/

## Architecture

```
CloudFront (journal.daoxiao.org) ── S3 (React build)
  │
  ▼  login / signup
Cognito User Pool  ──JWT (ID Token)──┐
                                      ▼
                          API Gateway (HTTP API)
                          JWT Authorizer (Cognito直結)
                                      │
                    ┌─────────┬───────┼───────┬─────────┐
                POST /entries GET /entries PUT /entries/{id} DELETE /entries/{id}
                    │         │             │             │
              create_entry list_entries update_entry  delete_entry   (Lambda, Python 3.12)
                    └─────────┴───────┬─────┴─────────────┘
                                      ▼
                           DynamoDB（entries テーブル）
                           PK: userId / SK: entryId
```

## なぜこの設計か

- **HTTP API（REST APIではなく）**: CognitoのJWTをネイティブ検証できる`JWT Authorizer`を標準搭載。REST APIより設定がシンプルで低コスト。CRUD程度の要件には十分。
- **Lambda言語をPython**: ユーザーがPython学習中のため、実務コードがそのまま学習教材になる。
- **DynamoDBシングルテーブル + PK=userId/SK=entryId**: ユーザーごとのQueryで完結し、Scanが不要。他ユーザーのデータへ到達する経路自体が存在しない設計（IDOR対策）。
- **IAMユーザーは新規作成せず既存(github-actions-portfolio-01)を拡張**: Phase毎にGitHub Secretsを増やさない方針を踏襲。
- **CI/CDのスコープはLambdaコード更新のみ**: Cognito/API Gateway/DynamoDB/IAMロードなどのインフラ変更はPhase 2と同様、ローカルから`terraform apply`で手動デプロイする。CI用IAMユーザーにIAMロール作成権限までは持たせない。フロントエンド(S3+CloudFront)のデプロイも同様に手動(`aws s3 sync`)。
- **S3+CloudFrontはPhase 1とは別バケット・別ディストリビューション**: Phase 3を完全に独立してデプロイ・破棄できるようにする方針を踏襲（Phase 1のリソースをimportしない）。

## デプロイ手順（初回）

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform
terraform init
terraform plan
terraform apply
```

apply完了後、outputsに表示される以下をReactアプリの環境変数(`.env.local`)に設定する：
- `api_endpoint`
- `cognito_user_pool_id`
- `cognito_user_pool_client_id`
- `frontend_bucket_name`（フロントエンドのデプロイ先）
- `cloudfront_distribution_id`（キャッシュ無効化用）

## React フロントエンド

```bash
cd aws-portfolio-03-serverless/frontend
npm install
cp .env.example .env.local   # terraform outputsの値を書き込む
npm start                    # ローカル確認
```

本番デプロイ（手動・Phase 1と同じコマンド体系）:
```bash
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

- 認証: `amazon-cognito-identity-js`でCognitoと直接通信（サインアップ→確認コード→ログイン→IDトークン取得）
- API呼び出し: 全リクエストのAuthorizationヘッダーにIDトークンを付与。401が返るとセッション切れとみなしログイン画面へ戻す
- ユーザーによる実機E2Eテスト済み（サインアップ〜確認コード〜ログイン〜insert/update/delete/logout、2026-07-11）

## 残タスク

- [ ] GitHub Actionsでのフロントエンド自動デプロイ（現状は手動`aws s3 sync`のみ）

---

# Phase 03 — サーバーレス感謝日記（日本語）

ステータス: ✅ 公開中 — https://journal.daoxiao.org/

構成・設計理由は上記英語セクション参照（同一内容）。

## フォルダ構成

```
aws-portfolio-03-serverless/
├── infrastructure/terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── cognito.tf         # User Pool + App Client
│   ├── dynamodb.tf        # entries テーブル
│   ├── lambda.tf          # 実行ロール + 4関数
│   ├── api_gateway.tf     # HTTP API + JWT Authorizer + ルート
│   ├── iam.tf             # 既存IAMユーザーへの権限追加
│   ├── s3_frontend.tf     # フロントエンド配信用S3バケット
│   ├── cloudfront.tf      # OAC + CloudFront（journal.daoxiao.org）
│   ├── acm.tf             # ACM証明書（us-east-1）
│   ├── route53.tf         # Aレコード(alias)
│   └── outputs.tf
├── backend/lambda/
│   ├── create_entry/handler.py
│   ├── list_entries/handler.py
│   ├── update_entry/handler.py
│   └── delete_entry/handler.py
└── frontend/
    ├── src/auth/cognito.js       # サインアップ/確認/ログイン/IDトークン取得
    ├── src/api/entries.js        # API Gatewayへのfetchラッパー
    ├── src/components/AuthScreen.js
    ├── src/components/JournalScreen.js
    └── src/App.js                # 認証状態で画面切替
```
