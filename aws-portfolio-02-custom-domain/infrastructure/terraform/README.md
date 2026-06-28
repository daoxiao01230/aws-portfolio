# Phase 02 — Terraform

Phase 1 の CloudFront に カスタムドメイン（`gratitude.daoxiao.org`）と HTTPS を追加する。

**import ブロック**（Terraform 1.5+）を使って Phase 1 の CloudFront distribution を
このフェーズの管理下に移し、エイリアスと ACM 証明書を適用する。

## 構成

| ファイル | 作成・操作されるリソース |
|---|---|
| `providers.tf` | AWS プロバイダー（ap-northeast-1）+ us-east-1 エイリアス |
| `variables.tf` | 入力変数（Phase 1 outputs + ドメイン情報） |
| `acm.tf` | ACM 証明書（us-east-1）+ DNS 検証レコード + 検証待機 |
| `cloudfront_update.tf` | Phase 1 の CF を **import** して alias + ACM 証明書を追加 |
| `route53.tf` | A エイリアスレコード（gratitude.daoxiao.org → CloudFront） |
| `outputs.tf` | website URL・CF Distribution ID・証明書 ARN |

## デプロイ手順

### Step 1: Phase 1 の出力値を取得

```bash
cd aws-portfolio-01-static-site/infrastructure/terraform

terraform output cloudfront_distribution_id
terraform output cloudfront_oac_id
terraform output s3_bucket_name
```

### Step 2: Phase 2 をデプロイ

```bash
cd aws-portfolio-02-custom-domain/infrastructure/terraform

terraform init

terraform apply \
  -var="cloudfront_distribution_id=<Step1で取得>" \
  -var="oac_id=<Step1で取得>" \
  -var="bucket_name=<Step1で取得>"
```

> `terraform apply` の初回実行時に import が自動で行われる。
> Phase 1 の tfstate から CF distribution が除去され、Phase 2 の tfstate に移動する。

### Step 3: 出力値の確認

```bash
terraform output
```

| Output | 内容 |
|---|---|
| `website_url` | `https://gratitude.daoxiao.org` |
| `cloudfront_distribution_id` | CF Distribution ID |
| `certificate_arn` | ACM 証明書 ARN（us-east-1） |

## 注意事項

- ACM 証明書の DNS 検証に数分かかる（`terraform apply` 中に自動で待機する）
- import 後は Phase 1 Terraform の `terraform apply` を単独で実行しないこと
  （CF distribution が Phase 2 の管理下に移っているため、Phase 1 が再作成しようとする）
- CloudFront の変更反映には最大 15 分かかる場合がある

## 削除

```bash
terraform destroy \
  -var="cloudfront_distribution_id=<value>" \
  -var="oac_id=<value>" \
  -var="bucket_name=<value>"
```
