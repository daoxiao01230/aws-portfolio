# Phase 01 — Terraform

S3（プライベートバケット）+ CloudFront（OAC）の静的ホスティング基盤を Terraform で構築する。

## 構成

| ファイル | 作成されるリソース |
|---|---|
| `providers.tf` | AWS プロバイダー設定 |
| `variables.tf` | 入力変数（バケット名・リージョン） |
| `main.tf` | S3 バケット・パブリックアクセスブロック・OAC・CloudFront ディストリビューション・バケットポリシー |
| `outputs.tf` | website URL・CF Distribution ID・S3 バケット名・OAC ID |

## デプロイ手順

```bash
cd aws-portfolio-01-static-site/infrastructure/terraform

# 1. 初期化
terraform init

# 2. 実行計画の確認
terraform plan -var="bucket_name=portfolio-01-gratitude-tf-2026"

# 3. デプロイ
terraform apply -var="bucket_name=portfolio-01-gratitude-tf-2026"
```

> `bucket_name` は AWS グローバルで一意である必要がある。

## 出力値の確認

```bash
terraform output
```

| Output | 用途 |
|---|---|
| `website_url` | CloudFront の公開 URL |
| `cloudfront_distribution_id` | GitHub Actions シークレット `CLOUDFRONT_DISTRIBUTION_ID` に設定 |
| `s3_bucket_name` | GitHub Actions シークレット `S3_BUCKET_NAME` に設定 |
| `cloudfront_oac_id` | Phase 2 Terraform の `-var="oac_id=..."` に使用 |

## 削除

```bash
terraform destroy -var="bucket_name=portfolio-01-gratitude-tf-2026"
```

`force_destroy = true` により、バケット内のファイルも自動削除される。
