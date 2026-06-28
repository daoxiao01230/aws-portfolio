# Portfolio 01 — Static Site Hosting

React app deployed to AWS with S3 + CloudFront, automated via GitHub Actions CI/CD, with infrastructure defined as code using both Terraform and CloudFormation.

## Architecture

```
GitHub (push to main)
        │
GitHub Actions
  ┌─────┴─────┐
[build]    [deploy] ← runs only on main push
  │            │
npm ci      npm ci
npm build   npm build
            aws s3 sync --delete
            cloudfront invalidation
        │
    S3 Bucket (private)
        │
 CloudFront (OAC)
        │
   HTTPS endpoint
```

## AWS Services Used

| Service | Purpose |
|---------|---------|
| S3 | Store static build files (private bucket) |
| CloudFront | CDN + HTTPS + OAC |
| IAM | Dedicated user for GitHub Actions (least privilege) |
| GitHub Actions | CI/CD — build check on PR, auto deploy on main |
| CloudFormation | Infrastructure as Code (option A) |
| Terraform | Infrastructure as Code (option B) |

## Full Setup Flow

```
1. Deploy infrastructure (Terraform or CloudFormation)
2. Create IAM user for GitHub Actions
3. Register GitHub Secrets (5 values)
4. Push to main → automatic deploy
```

## Step 1: Deploy Infrastructure

### Option A: Terraform

```bash
cd infrastructure/terraform
terraform init
terraform apply -var="bucket_name=your-bucket-name"
```

Outputs: `website_url`, `cloudfront_distribution_id`, `s3_bucket_name`

### Option B: CloudFormation

Deploy stacks in order: s3.yaml → cloudfront.yaml → iam.yaml

```bash
# 1. S3 bucket
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/s3.yaml \
  --stack-name portfolio-01-s3 \
  --parameter-overrides BucketName=your-bucket-name

# 2. CloudFront (use outputs from step 1)
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/cloudfront.yaml \
  --stack-name portfolio-01-cloudfront \
  --parameter-overrides \
    BucketName=your-bucket-name \
    BucketArn=arn:aws:s3:::your-bucket-name \
    BucketRegionalDomainName=your-bucket.s3.region.amazonaws.com
```

## Step 2: Create IAM User

Create a dedicated IAM user for GitHub Actions with least-privilege permissions.

### Option A: CloudFormation (recommended)

```bash
# Use outputs from cloudfront.yaml
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/iam.yaml \
  --stack-name portfolio-01-iam \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BucketName=your-bucket-name \
    CloudFrontDistributionId=your-distribution-id
```

After deploy: CloudFormation → Stacks → portfolio-01-iam → **Outputs tab** → copy `AccessKeyId` and `SecretAccessKey`

### Option B: AWS Console (manual)

1. IAM → Users → Create user
2. User name: `github-actions-portfolio`
3. Attach permissions → Create inline policy → paste JSON below:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Deploy",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_BUCKET_NAME",
        "arn:aws:s3:::YOUR_BUCKET_NAME/*"
      ]
    },
    {
      "Sid": "CloudFrontInvalidation",
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::YOUR_ACCOUNT_ID:distribution/YOUR_DISTRIBUTION_ID"
    }
  ]
}
```

4. After user is created → Security credentials tab → Create access key
5. Copy `Access key ID` and `Secret access key`

## Step 3: Setup GitHub Actions CI/CD

Add these secrets in GitHub → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `S3_BUCKET_NAME` | From Terraform/CFN output |
| `CLOUDFRONT_DISTRIBUTION_ID` | From Terraform/CFN output |

> `AWS_REGION` は不要。`ap-northeast-1` をワークフロー内にハードコード済み。

**CI/CD behavior:**
- `push` to `main` → build + deploy + CloudFront invalidation
- Pull Request → build check only (no deploy)
- Manual run → GitHub Actions tab → Run workflow

## Local Development

```bash
npm install
npm start
```

## Destroy All Resources

When you no longer need the infrastructure, delete everything with one command.

### Option A: Terraform

```bash
bash scripts/destroy-terraform.sh
```

`force_destroy = true` is set on the S3 bucket, so files are automatically deleted before the bucket is removed.

### Option B: CloudFormation

```bash
bash scripts/destroy-cloudformation.sh <bucket-name> <stack-name>

# Example:
bash scripts/destroy-cloudformation.sh \
  portfolio-01-gratitude-journal-2026 \
  portfolio-01-static-site
```

The script empties the S3 bucket first, then deletes the stack.

## Key Decisions

- S3 bucket is **private** — CloudFront accesses it via Origin Access Control (OAC), not public ACL
- 403/404 errors redirect to `index.html` to support client-side routing
- CI/CD uses 2 separate jobs: `build` (runs on all events) and `deploy` (main only)
- IAM user has least-privilege permissions — S3 write + CloudFront invalidation only, scoped to this project's resources
- Both Terraform and CloudFormation produce identical infrastructure
- `force_destroy = true` on S3 (Terraform only) — allows one-command teardown

---

# Portfolio 01 — 静的サイトホスティング

ReactアプリをAWSにデプロイする。S3 + CloudFrontで静的コンテンツを配信し、GitHub Actions CI/CDで自動デプロイ、インフラはTerraformとCloudFormationの2種類でコード化している。

## アーキテクチャ

```
GitHub（mainへpush）
        │
GitHub Actions
  ┌─────┴─────┐
[build]    [deploy] ← mainへのpushのみ実行
  │            │
npm ci      npm ci
npm build   npm build
            aws s3 sync --delete
            CloudFront Invalidation
        │
    S3バケット（プライベート）
        │
 CloudFront（OAC経由）
        │
   HTTPSエンドポイント
```

## 使用AWSサービス

| サービス | 用途 |
|---------|------|
| S3 | 静的ファイル（HTML/CSS/JS）の保存（プライベートバケット） |
| CloudFront | CDN + HTTPS + OAC認証 |
| IAM | GitHub Actions専用ユーザー（最小権限） |
| GitHub Actions | CI/CD — PRでビルド確認、mainで自動デプロイ |
| CloudFormation | Infrastructure as Code（選択肢A） |
| Terraform | Infrastructure as Code（選択肢B） |

## セットアップ全体の流れ

```
1. インフラをデプロイ（TerraformまたはCloudFormation）
2. GitHub Actions用IAMユーザーを作成
3. GitHub Secretsに5つの値を登録
4. mainへpush → 自動デプロイ
```

## Step 1: インフラのデプロイ

### 選択肢A: Terraform

```bash
cd infrastructure/terraform
terraform init
terraform apply -var="bucket_name=バケット名"
```

実行後の出力: `website_url`、`cloudfront_distribution_id`、`s3_bucket_name`

### 選択肢B: CloudFormation

スタックのデプロイ順序: s3.yaml → cloudfront.yaml → iam.yaml

```bash
# 1. S3バケット
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/s3.yaml \
  --stack-name portfolio-01-s3 \
  --parameter-overrides BucketName=バケット名

# 2. CloudFront（step 1の出力値を使用）
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/cloudfront.yaml \
  --stack-name portfolio-01-cloudfront \
  --parameter-overrides \
    BucketName=バケット名 \
    BucketArn=arn:aws:s3:::バケット名 \
    BucketRegionalDomainName=バケット名.s3.リージョン.amazonaws.com
```

## Step 2: IAMユーザーの作成

GitHub Actions専用のIAMユーザーを最小権限で作成する。

### 選択肢A: CloudFormation（推奨）

```bash
# cloudfront.yamlの出力値を使用
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/iam.yaml \
  --stack-name portfolio-01-iam \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BucketName=バケット名 \
    CloudFrontDistributionId=DistributionID
```

デプロイ後: CloudFormation → スタック → portfolio-01-iam → **Outputsタブ** → `AccessKeyId`と`SecretAccessKey`をコピー

### 選択肢B: AWSコンソール（手動）

1. IAM → ユーザー → ユーザーを作成
2. ユーザー名: `github-actions-portfolio`
3. 「ポリシーを直接アタッチ」→「インラインポリシーを作成」→ 以下JSONを貼り付け:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Deploy",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::バケット名",
        "arn:aws:s3:::バケット名/*"
      ]
    },
    {
      "Sid": "CloudFrontInvalidation",
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::AWSアカウントID:distribution/DistributionID"
    }
  ]
}
```

4. ユーザー作成後 →「セキュリティ認証情報」タブ →「アクセスキーを作成」
5. `アクセスキーID`と`シークレットアクセスキー`をコピー（この画面でしか確認できない）

## Step 3: GitHub Secrets の登録

GitHub → Settings → Secrets and variables → Actions で以下の5つを登録:

| Secret名 | 設定値 |
|----------|--------|
| `AWS_ACCESS_KEY_ID` | IAMユーザーのアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | IAMユーザーのシークレットアクセスキー |
| `AWS_REGION` | リージョン（例: `us-east-1`） |
| `S3_BUCKET_NAME` | Terraform/CFNの出力値 |
| `CLOUDFRONT_DISTRIBUTION_ID` | Terraform/CFNの出力値 |

**CI/CDの動作:**
- `main`へpush → ビルド + S3デプロイ + CloudFront Invalidation
- Pull Request → ビルド確認のみ（デプロイしない）
- 手動実行 → ActionsタブのRun workflowボタンから実行

## ローカル開発

```bash
npm install
npm start
```

## 全リソースの削除

不要になったインフラを一コマンドで全削除できる。

### 選択肢A: Terraform

```bash
bash scripts/destroy-terraform.sh
```

S3バケットに`force_destroy = true`が設定されているため、中身のファイルを自動削除してからバケットを削除する。

### 選択肢B: CloudFormation

```bash
bash scripts/destroy-cloudformation.sh <バケット名> <スタック名>

# 例:
bash scripts/destroy-cloudformation.sh \
  portfolio-01-gratitude-journal-2026 \
  portfolio-01-static-site
```

スクリプトがS3バケットを先に空にしてからスタックを削除する。

## 設計上の判断

- S3バケットは**プライベート** — CloudFrontはOAC（Origin Access Control）経由でのみアクセス。直接公開しない。
- 403/404エラーは`index.html`にリダイレクト — ReactRouterのクライアントサイドルーティングを機能させるため。
- CI/CDは2ジョブ構成: `build`（全イベントで実行）と`deploy`（mainのみ）に分離。
- IAMユーザーは最小権限 — このプロジェクトのS3書き込みとCloudFront Invalidationのみ許可。
- TerraformとCloudFormationは同一のインフラを構築する。用途に応じてどちらかを選択。
- S3に`force_destroy = true`（Terraformのみ）— 一コマンドで全削除できるようにするため。
