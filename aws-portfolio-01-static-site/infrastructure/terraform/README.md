# Phase 01 — Terraform

Builds S3 (private bucket) + CloudFront (OAC) + IAM static hosting infrastructure using Terraform.

## Configuration

| File | Resources Created |
|------|------------------|
| `providers.tf` | AWS provider configuration |
| `variables.tf` | Input variables (bucket name, region) |
| `main.tf` | S3 bucket, public access block, OAC, CloudFront distribution, bucket policy, IAM user + policy + access key |
| `outputs.tf` | Website URL, CF distribution ID, S3 bucket name, OAC ID, IAM access key credentials |

## Deploy

```bash
cd aws-portfolio-01-static-site/infrastructure/terraform

# 1. Initialize
terraform init

# 2. Preview changes
terraform plan -var="bucket_name=your-bucket-name"

# 3. Deploy
terraform apply -var="bucket_name=your-bucket-name"
```

> `bucket_name` must be globally unique across all AWS accounts.

## Outputs

```bash
terraform output
```

| Output | Purpose |
|--------|---------|
| `website_url` | CloudFront public URL |
| `cloudfront_distribution_id` | Set as GitHub Secret: `CLOUDFRONT_DISTRIBUTION_ID` |
| `s3_bucket_name` | Set as GitHub Secret: `S3_BUCKET_NAME` |
| `cloudfront_oac_id` | Used by Phase 02 Terraform: `-var="oac_id=..."` |
| `github_actions_access_key_id` | Set as GitHub Secret: `AWS_ACCESS_KEY_ID` |
| `github_actions_secret_access_key` | Set as GitHub Secret: `AWS_SECRET_ACCESS_KEY` (sensitive) |

Retrieve the sensitive secret key:

```bash
terraform output -raw github_actions_secret_access_key
```

> Copy directly from terminal into GitHub Secrets — do not relay through other tools.

## Destroy

```bash
# Git Bash / WSL (run from aws-portfolio-01-static-site/)
bash scripts/destroy-terraform.sh

# PowerShell (run from aws-portfolio-01-static-site\)
.\scripts\destroy-terraform.ps1
```

`force_destroy = true` on S3 — bucket contents are deleted automatically before the bucket is removed.

---

# Phase 01 — Terraform（日本語）

S3（プライベートバケット）+ CloudFront（OAC）+ IAM の静的ホスティング基盤を Terraform で構築する。

## 構成

| ファイル | 作成されるリソース |
|---------|-----------------|
| `providers.tf` | AWS プロバイダー設定 |
| `variables.tf` | 入力変数（バケット名・リージョン） |
| `main.tf` | S3 バケット・パブリックアクセスブロック・OAC・CloudFront ディストリビューション・バケットポリシー・IAMユーザー + ポリシー + アクセスキー |
| `outputs.tf` | website URL・CF Distribution ID・S3 バケット名・OAC ID・IAM認証情報 |

## デプロイ手順

```bash
cd aws-portfolio-01-static-site/infrastructure/terraform

# 1. 初期化
terraform init

# 2. 実行計画の確認
terraform plan -var="bucket_name=バケット名"

# 3. デプロイ
terraform apply -var="bucket_name=バケット名"
```

> `bucket_name` は AWS グローバルで一意である必要がある。

## 出力値の確認

```bash
terraform output
```

| Output | 用途 |
|--------|------|
| `website_url` | CloudFront の公開 URL |
| `cloudfront_distribution_id` | GitHub Secret: `CLOUDFRONT_DISTRIBUTION_ID` に設定 |
| `s3_bucket_name` | GitHub Secret: `S3_BUCKET_NAME` に設定 |
| `cloudfront_oac_id` | Phase 02 Terraform の `-var="oac_id=..."` に使用 |
| `github_actions_access_key_id` | GitHub Secret: `AWS_ACCESS_KEY_ID` に設定 |
| `github_actions_secret_access_key` | GitHub Secret: `AWS_SECRET_ACCESS_KEY` に設定（sensitive） |

シークレットキーの取得：

```bash
terraform output -raw github_actions_secret_access_key
```

> ターミナルの出力を直接 GitHub Secrets に貼り付ける。他のツール経由で転記しない。

## 削除

```bash
# Git Bash / WSL（aws-portfolio-01-static-site/ から実行）
bash scripts/destroy-terraform.sh

# PowerShell（aws-portfolio-01-static-site\ から実行）
.\scripts\destroy-terraform.ps1
```

`force_destroy = true` により、バケット内のファイルも自動削除される。
