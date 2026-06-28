# Portfolio 02 — Custom Domain + HTTPS

Phase 01 の S3 + CloudFront に、カスタムドメイン `gratitude.daoxiao.org` と HTTPS 証明書を追加する。

## Architecture

```
ユーザー
  │
  │ https://gratitude.daoxiao.org
  ▼
Route 53（A レコード / エイリアス）
  │
  ▼
CloudFront（ACM 証明書 + カスタムドメイン）
  │
  ▼
S3（Phase 01 から継続）
```

## Phase 01 からの変更点

| 項目 | Phase 01 | Phase 02 |
|------|----------|----------|
| URL | `*.cloudfront.net` | `gratitude.daoxiao.org` |
| 証明書 | CloudFront デフォルト | ACM（独自証明書） |
| DNS | なし | Route 53 A レコード追加 |
| S3 | 新規作成 | Phase 01 を継続使用 |

## AWS Services

| サービス | 用途 |
|---------|------|
| ACM | `gratitude.daoxiao.org` の SSL/TLS 証明書（us-east-1 必須） |
| Route 53 | DNS A レコード（エイリアス）で CF に向ける |
| CloudFront | Phase 01 のスタックを更新：カスタムドメイン + ACM 証明書追加 |

## デプロイ順序

```
1. acm.yaml          → portfolio-02-acm         (us-east-1)
2. cloudfront-v2.yaml → portfolio-01-cloudfront  (ap-northeast-1 / UPDATE)
3. route53.yaml      → portfolio-02-route53      (ap-northeast-1)
```

## Step 1: ACM 証明書の作成（us-east-1）

```bash
TEMPLATE=$(Get-Content infrastructure/cloudformation/acm.yaml -Raw -Encoding UTF8)
aws cloudformation create-stack \
  --stack-name portfolio-02-acm \
  --template-body $TEMPLATE \
  --region us-east-1 \
  --parameters ParameterKey=HostedZoneId,ParameterValue=YOUR_HOSTED_ZONE_ID

# 完了を待機（DNS 検証のため数分かかる）
aws cloudformation wait stack-create-complete \
  --stack-name portfolio-02-acm \
  --region us-east-1
```

## Step 2: CloudFront を更新（portfolio-01-cloudfront を UPDATE）

```bash
aws cloudformation update-stack \
  --stack-name portfolio-01-cloudfront \
  --template-body $TEMPLATE \
  --parameters \
    ParameterKey=BucketName,ParameterValue=portfolio-01-gratitude-2026-v2 \
    ParameterKey=BucketArn,ParameterValue=arn:aws:s3:::portfolio-01-gratitude-2026-v2 \
    ParameterKey=BucketRegionalDomainName,ParameterValue=portfolio-01-gratitude-2026-v2.s3.ap-northeast-1.amazonaws.com \
    ParameterKey=AcmCertificateArn,ParameterValue=YOUR_CERT_ARN
```

## Step 3: Route 53 DNS レコード追加

```bash
aws cloudformation create-stack \
  --stack-name portfolio-02-route53 \
  --template-body $TEMPLATE \
  --parameters \
    ParameterKey=HostedZoneId,ParameterValue=YOUR_HOSTED_ZONE_ID \
    ParameterKey=CloudFrontDomainName,ParameterValue=YOUR_CF_DOMAIN
```

## Key Decisions

- ACM は **us-east-1 のみ**対応（CloudFront の仕様）
- Route 53 エイリアスレコードは CloudFront 専用の Hosted Zone ID `Z2FDTNDATAQYW2` を使う（固定値）
- Phase 01 の S3 はそのまま再利用（データ移行不要）
- CloudFront の既存スタックを UPDATE することで、ダウンタイムなしで切り替え可能
