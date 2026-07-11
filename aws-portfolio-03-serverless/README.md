# Phase 03 — Serverless Gratitude Journal

Status: 🚧 In Progress（設計・Terraformスケルトン作成済み・未デプロイ）

## Architecture

```
React (aws-portfolio-03-serverless/react)
  │  login / signup
  ▼
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
- **CI/CDのスコープはLambdaコード更新のみ**: Cognito/API Gateway/DynamoDB/IAMロードなどのインフラ変更はPhase 2と同様、ローカルから`terraform apply`で手動デプロイする。CI用IAMユーザーにIAMロール作成権限までは持たせない。

## デプロイ手順（初回）

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform
terraform init
terraform plan
terraform apply
```

apply完了後、outputsに表示される以下をReactアプリの環境変数に設定する：
- `api_endpoint`
- `cognito_user_pool_id`
- `cognito_user_pool_client_id`

## React フロントエンド

```bash
cd aws-portfolio-03-serverless/react
npm install
cp .env.example .env.local   # terraform outputsの値を書き込む
npm start
```

- 認証: `amazon-cognito-identity-js`でCognitoと直接通信（サインアップ→確認コード→ログイン→IDトークン取得）
- API呼び出し: 全リクエストのAuthorizationヘッダーにIDトークンを付与。401が返るとセッション切れとみなしログイン画面へ戻す
- `npm run build` でのビルド確認済み（バックエンド未デプロイのためランタイム動作は未確認）

## 残タスク（未着手）

- [ ] `terraform apply` 実行・実機デプロイ確認
- [ ] `.env.local` にterraform outputsを設定し、エンドツーエンド動作確認（サインアップ→ログイン→日記のCRUD）
- [ ] コストの確認（Cost-Estimation.mdへ追記）

---

# Phase 03 — サーバーレス感謝日記（日本語）

ステータス: 🚧 進行中（設計・Terraformスケルトン作成済み・未デプロイ）

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
│   └── outputs.tf
├── src/lambda/
│   ├── create_entry/handler.py
│   ├── list_entries/handler.py
│   ├── update_entry/handler.py
│   └── delete_entry/handler.py
└── react/
    ├── src/auth/cognito.js       # サインアップ/確認/ログイン/IDトークン取得
    ├── src/api/entries.js        # API Gatewayへのfetchラッパー
    ├── src/components/AuthScreen.js
    ├── src/components/JournalScreen.js
    └── src/App.js                # 認証状態で画面切替
```
