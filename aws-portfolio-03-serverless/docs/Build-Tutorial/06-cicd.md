[目次](./README.md) | 前へ: [Part 4 — フロントエンド(まず動かす)](./04-frontend-quickstart.md) / [Part 5 — フロントエンド(段階的に理解)](./05-frontend-deep-dive.md) | 次へ: [Part 7 — 確認チェックリスト](./07-verification-checklist.md)

---

# Part 6 — GitHub Actionsで自動デプロイを設定する

ここまでで手動デプロイ（`terraform apply`や`npm run build && aws s3 sync`を
自分で実行する）はできる状態になっている。Part 6では、「コードをpushしたら
自動でデプロイされる」ようにする。

### 6-1. 全体方針

このプロジェクトでは、**インフラ（Cognito・DynamoDB・API Gateway・S3/
CloudFrontの作成）は自動化しない**。自動化するのは「できあがったインフラに
対して、アプリケーションコードを更新する」部分だけ。

理由: CI（GitHub Actions）が使うIAMユーザーに「インフラを作る権限」まで
持たせると、GitHub Actionsの設定ミスや悪意あるPull Requestが原因で
AWSアカウントの構成そのものが変更されるリスクがある。「Lambdaのコードを
更新する」「S3の中身を差し替える」だけに権限を絞っておけば、被害の範囲を
限定できる。

そのため、ワークフローは2つに分ける:
- `deploy-03-serverless.yml` — `backend/lambda/**`が変更されたらLambdaの
  コードだけ更新する
- `deploy-03-frontend.yml` — `frontend/**`が変更されたらReactをビルドして
  S3+CloudFrontに反映する

### 6-2. CI専用のIAM権限を絞って用意する

まず、GitHub Actionsが使うIAMユーザーを用意する（初回のみ）。
Part 2または3で既にIAMユーザーを作っていなければ、以下で新規作成する:

```bash
aws iam create-user --user-name github-actions-portfolio-03
aws iam create-access-key --user-name github-actions-portfolio-03
# 表示される AccessKeyId と SecretAccessKey を保存する
```

このユーザーに、Lambdaコード更新用の権限だけを追加する
（Terraform版なら`iam.tf`の`aws_iam_user_policy.github_actions_lambda_deploy`、
CloudFormation版なら`iam-cicd.yaml`が、まさにこの権限を作る役目）。
Part 2または3を最後まで終えていれば、この権限は既に付与済みのはず。

### 6-3. Lambdaデプロイ用ワークフロー

`.github/workflows/deploy-03-serverless.yml`:
```yaml
name: Portfolio 03 - Lambda Deploy

on:
  push:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/backend/lambda/**'
  pull_request:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/backend/lambda/**'
  workflow_dispatch:

defaults:
  run:
    working-directory: aws-portfolio-03-serverless

jobs:
  deploy:
    name: Update Lambda function code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Zip Lambda functions
        run: |
          for fn in create_entry list_entries update_entry delete_entry; do
            cd "backend/lambda/$fn"
            zip -r "../../../$fn.zip" .
            cd -
          done

      - name: Configure AWS credentials
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1

      - name: Update function code
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        run: |
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-create-entry \
            --zip-file fileb://create_entry.zip
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-list-entries \
            --zip-file fileb://list_entries.zip
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-update-entry \
            --zip-file fileb://update_entry.zip
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-delete-entry \
            --zip-file fileb://delete_entry.zip
```

### 6-4. フロントエンドデプロイ用ワークフロー

`.github/workflows/deploy-03-frontend.yml`:
```yaml
name: Portfolio 03 - Frontend Deploy

on:
  push:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/frontend/**'
  pull_request:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/frontend/**'
  workflow_dispatch:

defaults:
  run:
    working-directory: aws-portfolio-03-serverless/frontend

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    env:
      REACT_APP_AWS_REGION: ap-northeast-1
      REACT_APP_API_ENDPOINT: ${{ vars.PHASE3_API_ENDPOINT }}
      REACT_APP_COGNITO_USER_POOL_ID: ${{ vars.PHASE3_COGNITO_USER_POOL_ID }}
      REACT_APP_COGNITO_CLIENT_ID: ${{ vars.PHASE3_COGNITO_CLIENT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: 'aws-portfolio-03-serverless/frontend/package-lock.json'
      - run: npm ci
      - run: npm run build

  deploy:
    name: Deploy to AWS
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    env:
      REACT_APP_AWS_REGION: ap-northeast-1
      REACT_APP_API_ENDPOINT: ${{ vars.PHASE3_API_ENDPOINT }}
      REACT_APP_COGNITO_USER_POOL_ID: ${{ vars.PHASE3_COGNITO_USER_POOL_ID }}
      REACT_APP_COGNITO_CLIENT_ID: ${{ vars.PHASE3_COGNITO_CLIENT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: 'aws-portfolio-03-serverless/frontend/package-lock.json'
      - run: npm ci
      - run: npm run build
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1
      - name: Deploy to S3
        run: aws s3 sync build/ s3://${{ vars.PHASE3_S3_BUCKET_NAME }} --delete
      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ vars.PHASE3_CLOUDFRONT_DIST_ID }} \
            --paths "/*"
```

### 6-5. GitHubリポジトリにSecrets/Variablesを登録する

GitHub → 対象リポジトリ → **Settings** → **Secrets and variables** →
**Actions** を開く。この画面には上部に **「Secrets」タブ**と
**「Variables」タブ**の2つがあり、**完全に別の名前空間**になっている点に
特に注意する。

> ⚠️ **実際にここでハマった経験談**: `${{ vars.PHASE3_S3_BUCKET_NAME }}`と
> ワークフローに書いてあるのに、値をSecretsタブに登録してしまうと、
> `vars.*`からは参照できず**空文字列**として扱われる。結果、
> `aws s3 sync build/ s3:// --delete`のようにバケット名が空のコマンドに
> なり、`Invalid bucket name ""`という分かりにくいエラーで失敗する。
> 「Secretsに登録したのに動かない」場合は、まずタブを間違えていないか
> 疑うこと。

**「Secrets」タブ**に登録する（機密情報・AWS認証情報）:

| Secret名 | 値 |
|---|---|
| `AWS_ACCESS_KEY_ID` | 6-2で作ったIAMユーザーのアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | 同シークレットアクセスキー |

**「Variables」タブ**に登録する（機密ではない設定値。理由: どのみち
ビルド後のJSファイルに埋め込まれ、ブラウザの開発者ツールから誰でも
見える値のため、Secretsとして隠す意味がない）:

| Variable名 | 値 |
|---|---|
| `PHASE3_API_ENDPOINT` | `terraform output api_endpoint`の値 |
| `PHASE3_COGNITO_USER_POOL_ID` | `terraform output cognito_user_pool_id`の値 |
| `PHASE3_COGNITO_CLIENT_ID` | `terraform output cognito_user_pool_client_id`の値 |
| `PHASE3_S3_BUCKET_NAME` | `terraform output frontend_bucket_name`の値 |
| `PHASE3_CLOUDFRONT_DIST_ID` | `terraform output cloudfront_distribution_id`の値 |

### 6-6. 動作確認

```bash
git add .
git commit -m "test: trigger CI"
git push origin main
```

GitHubリポジトリの「Actions」タブを開き、`Portfolio 03 - Lambda Deploy`と
`Portfolio 03 - Frontend Deploy`が実行され、両方成功（緑のチェックマーク）に
なることを確認する。

> 💡 pushした変更が`backend/lambda/**`だけならLambda Deployのみ、
> `frontend/**`だけならFrontend Deployのみが起動する（`paths`フィルターの
> おかげ）。両方を同時に変更してpushすれば、両方が並行して起動する。

---

[目次](./README.md) | 前へ: [Part 4 — フロントエンド(まず動かす)](./04-frontend-quickstart.md) / [Part 5 — フロントエンド(段階的に理解)](./05-frontend-deep-dive.md) | 次へ: [Part 7 — 確認チェックリスト](./07-verification-checklist.md)
