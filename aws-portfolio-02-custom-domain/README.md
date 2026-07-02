# Portfolio 02 — Custom Domain + HTTPS

✅ **Live**: [https://gratitude.daoxiao.org/](https://gratitude.daoxiao.org/)

Adds a custom domain (`gratitude.daoxiao.org`) and a dedicated HTTPS certificate on top of Phase 01's S3 + CloudFront static site.

## Architecture

```
User
  │
  │ https://gratitude.daoxiao.org
  ▼
Route 53 (A record / alias)
  │
  ▼
CloudFront (ACM certificate + custom domain)
  │
  ▼
S3 (reused from Phase 01)
```

## What changed from Phase 01

| Item | Phase 01 | Phase 02 |
|------|----------|----------|
| URL | `*.cloudfront.net` | `gratitude.daoxiao.org` |
| Certificate | CloudFront default | ACM (dedicated certificate) |
| DNS | none | Route 53 A record (alias) |
| S3 | newly created | reused from Phase 01 (no data migration) |

## AWS Services

| Service | Purpose |
|---------|---------|
| ACM | SSL/TLS certificate for `gratitude.daoxiao.org` (must be `us-east-1` for CloudFront) |
| Route 53 | A record (alias) pointing to CloudFront |
| CloudFront | Phase 01's distribution, updated in place via Terraform `import` |

## Deploy (Terraform)

This phase is Terraform-only — see [Key Decisions](#key-decisions) for why the originally-planned CloudFormation path isn't used.

```bash
# Step 1: get Phase 01 outputs
cd aws-portfolio-01-static-site/infrastructure/terraform
terraform output cloudfront_distribution_id
terraform output cloudfront_oac_id
terraform output s3_bucket_name

# Step 2: deploy Phase 02 (auto-imports Phase 01's CloudFront distribution)
cd aws-portfolio-02-custom-domain/infrastructure/terraform
terraform init
terraform apply \
  -var="cloudfront_distribution_id=<from Step 1>" \
  -var="oac_id=<from Step 1>" \
  -var="bucket_name=<from Step 1>"

# Step 3: verify
terraform output   # website_url, cloudfront_distribution_id, certificate_arn
```

Full step-by-step (including the `import` mechanics): [`infrastructure/terraform/README.md`](./infrastructure/terraform/README.md)

## CloudFormation templates (reference only — not deployable)

`infrastructure/cloudformation/` (`acm.yaml`, `cloudfront-v2.yaml`, `route53.yaml`) reflects the original plan to implement every phase in both Terraform and CloudFormation, matching Phase 01. `cloudfront-v2.yaml` was designed to `UPDATE` the Phase 01 CloudFormation stack (`portfolio-01-cloudfront`) — but that stack was deleted when Phase 01 migrated to Terraform. With nothing left to update, this phase was implemented in Terraform only, using an `import` block to bring Phase 01's existing CloudFront distribution under Terraform management instead of recreating it. The templates are kept for reference but cannot be deployed as-is.

## Key Decisions

- ACM certificates for CloudFront must be requested in **`us-east-1`**, regardless of where the rest of the stack lives — a CloudFront-specific requirement.
- Terraform's `import` block reuses Phase 01's existing CloudFront distribution instead of creating a new one — no downtime, no re-provisioning.
- Once imported, Phase 01's Terraform must not be `apply`-ed standalone anymore (the distribution now lives in Phase 02's state).
- Route 53 alias records to CloudFront always use the fixed CloudFront hosted zone ID `Z2FDTNDATAQYW2`.
- Pivoted from the planned Terraform+CloudFormation dual implementation to Terraform-only, after Phase 01's CloudFormation stack was deleted during its own Terraform migration (see above).

## Troubleshooting

After deployment, the domain kept resolving as `NXDOMAIN` even though every AWS-side setting (Route 53 records, nameservers) looked correct. The root cause turned out to be a registrar-side `clientHold` status (from an unconfirmed Whois verification email) — not DNS propagation delay. Full diagnostic walkthrough (RDAP-based, since `whois` wasn't available locally): [`docs/troubleshooting.md`](./docs/troubleshooting.md)

---

# Portfolio 02 — カスタムドメイン + HTTPS（日本語）

✅ **公開中**：[https://gratitude.daoxiao.org/](https://gratitude.daoxiao.org/)

Phase 01 の S3 + CloudFront に、カスタムドメイン `gratitude.daoxiao.org` と専用の HTTPS 証明書を追加する。

## アーキテクチャ

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
S3（Phase 01 から継続利用）
```

## Phase 01 からの変更点

| 項目 | Phase 01 | Phase 02 |
|------|----------|----------|
| URL | `*.cloudfront.net` | `gratitude.daoxiao.org` |
| 証明書 | CloudFront デフォルト | ACM（専用証明書） |
| DNS | なし | Route 53 A レコード（エイリアス） |
| S3 | 新規作成 | Phase 01 を継続使用（データ移行不要） |

## 使用AWSサービス

| サービス | 用途 |
|---------|------|
| ACM | `gratitude.daoxiao.org` のSSL/TLS証明書（CloudFrontの制約により`us-east-1`必須） |
| Route 53 | CloudFrontへ向けるAレコード（エイリアス） |
| CloudFront | Phase 01のディストリビューションをTerraformの`import`で引き継いで更新 |

## デプロイ（Terraform）

このフェーズはTerraformのみで構成されている。当初計画していたCloudFormation経路を使わない理由は[Key Decisions](#key-decisions-1)を参照。

```bash
# Step 1: Phase 01 の出力値を取得
cd aws-portfolio-01-static-site/infrastructure/terraform
terraform output cloudfront_distribution_id
terraform output cloudfront_oac_id
terraform output s3_bucket_name

# Step 2: Phase 02 をデプロイ（Phase 01 の CloudFront distribution を自動 import）
cd aws-portfolio-02-custom-domain/infrastructure/terraform
terraform init
terraform apply \
  -var="cloudfront_distribution_id=<Step1で取得した値>" \
  -var="oac_id=<Step1で取得した値>" \
  -var="bucket_name=<Step1で取得した値>"

# Step 3: 出力値の確認
terraform output   # website_url, cloudfront_distribution_id, certificate_arn
```

詳細手順（`import`の仕組みを含む）：[`infrastructure/terraform/README.md`](./infrastructure/terraform/README.md)

## CloudFormationテンプレート（参考のみ・デプロイ不可）

`infrastructure/cloudformation/`（`acm.yaml`・`cloudfront-v2.yaml`・`route53.yaml`）は、Phase 01と同様に全フェーズをTerraformとCloudFormationの両方で実装する当初計画の名残。`cloudfront-v2.yaml` はPhase 01のCloudFormationスタック（`portfolio-01-cloudfront`）を`UPDATE`する設計だったが、Phase 01がTerraformへ移行した際にそのスタック自体が削除された。更新対象が存在しなくなったため、本フェーズはTerraformのみで実装し、`import`ブロックでPhase 01の既存CloudFrontディストリビューションをTerraform管理下に取り込む方式に切り替えた。テンプレートは参考として残しているが、このままではデプロイできない。

## Key Decisions

- CloudFront用のACM証明書は、他のリソースのリージョンに関わらず**`us-east-1`**でのみリクエスト可能（CloudFront固有の制約）。
- Terraformの`import`ブロックでPhase 01の既存CloudFrontディストリビューションを再利用し、新規作成しない → ダウンタイムなし、再プロビジョニング不要。
- import後は、Phase 01のTerraformを単独で`apply`しないこと（ディストリビューションはPhase 02のstateに移っているため）。
- CloudFrontへのRoute 53エイリアスレコードは、固定のCloudFront用Hosted Zone ID `Z2FDTNDATAQYW2` を使用する。
- 当初計画していたTerraform＋CloudFormationの二重実装から、本フェーズのみTerraform単独に方針転換（Phase 01のTerraform移行でCloudFormationスタックが削除されたため、上記の通り）。

## トラブルシューティング

デプロイ後、Route 53側の設定（レコード・ネームサーバー）は全て正しく見えるのに、ドメインが`NXDOMAIN`のまま解決しない状態が続いた。原因はDNS伝播遅延ではなく、レジストラ側の`clientHold`ステータス（Whois確認メール未対応）だった。診断の全手順（`whois`コマンドが無い環境でのRDAPによる代替診断を含む）：[`docs/troubleshooting.md`](./docs/troubleshooting.md)
