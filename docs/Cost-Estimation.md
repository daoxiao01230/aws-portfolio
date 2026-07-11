# Cost Estimation — AWS Portfolio

Pricing based on AWS Tokyo region (ap-northeast-1) as of 2026.
All estimates assume **low-traffic portfolio usage** (~1,000 visits/month).

---

## Phase 01 — Static Site Hosting

### Services Used

| Service | Usage | Free Tier | Estimated Monthly Cost |
|---------|-------|-----------|----------------------|
| S3 Storage | ~2 MB (build files) | 5 GB / 12 months | **$0.00** |
| S3 Requests | ~500 PUT/month (CI/CD deploys) | 2,000 PUT / 12 months | **$0.00** |
| CloudFront Data Transfer | ~0.5 GB/month | 1 TB / always free | **$0.00** |
| CloudFront Requests | ~10,000 req/month | 10M req / always free | **$0.00** |
| CloudFront Invalidations | ~10 paths/month | 1,000 paths / always free | **$0.00** |
| IAM | — | Always free | **$0.00** |
| GitHub Actions | ~5 min/deploy × 10 deploys | Unlimited (public repo) | **$0.00** |

### Phase 01 Total

| Scenario | Monthly | Annual |
|----------|---------|--------|
| Within Free Tier (first 12 months) | **$0.00** | **$0.00** |
| After Free Tier expires | **~$0.01** | **~$0.12** |

> Phase 01 is effectively free. S3 storage cost after free tier: $0.025/GB = ~$0.00005/month for 2MB.

---

## Phase 02 — Custom Domain + HTTPS (Planned)

### Additional Services

| Service | Usage | Free Tier | Estimated Monthly Cost |
|---------|-------|-----------|----------------------|
| ACM Certificate | 1 certificate | Always free (public cert) | **$0.00** |
| Route 53 Hosted Zone | 1 zone | None | **$0.50** |
| Route 53 DNS Queries | ~10,000/month | 1M queries included in $0.50 | **$0.00** |

### Phase 02 Total (incremental)

| Scenario | Monthly | Annual |
|----------|---------|--------|
| Added cost vs Phase 01 | **$0.50** | **$6.00** |

> Route 53 hosted zone is the only meaningful cost at portfolio scale.

---

## Phase 03 — Serverless Application (Deployed 2026-07-11)

### Additional Services

| Service | Usage (actual portfolio scale) | Free Tier | Estimated Monthly Cost |
|---------|-------|-----------|----------------------|
| Cognito User Pool (Essentials tier) | 1 test user | 10,000 MAU/month, always free | **$0.00** |
| API Gateway (HTTP API) | ~100 requests/month | 1M requests / 12 months, then $1.00/million | **$0.00** |
| Lambda (4 functions) | ~400 invocations/month | 1M requests + 400,000 GB-seconds, always free | **$0.00** |
| DynamoDB (on-demand) storage | <1 MB | 25 GB, always free | **$0.00** |
| DynamoDB (on-demand) requests | ~500 reads + 200 writes/month | None for on-demand mode ($0.25/M read, $1.25/M write, US baseline; Tokyo slightly higher) | **$0.00** (well under $0.01) |

### Phase 03 Total (incremental)

| Scenario | Monthly | Annual |
|----------|---------|--------|
| Current portfolio-scale usage | **~$0.00** | **~$0.00** |
| After API Gateway free tier expires (12 months) | **~$0.01** | **~$0.12** |

> Unlike Phase 01/02, DynamoDB on-demand mode has **no free tier for request costs** (only the 25 GB storage allowance is free) — but at portfolio-demo traffic levels the per-request cost rounds to zero. If this app ever gets real user traffic, DynamoDB request cost is the line item to watch first (API Gateway and Lambda free tiers are far larger).

---

## Phase 04–06 — Cost Preview (Planned)

| Phase | Key Services Added | Estimated Monthly Cost |
|-------|-------------------|----------------------|
| 04 Observability | CloudWatch Logs, X-Ray, SNS | ~$0.00–$1.00 |
| 05 Containers | ECS Fargate, ALB, RDS | ~$30–$80 |
| 06 DevOps | CodePipeline, CodeBuild | ~$1.00–$5.00 |

> Phase 05 (Containers) has the largest cost jump — Fargate + ALB + RDS run continuously even with zero traffic. Run only when needed to minimize cost.

---

## Free Tier Summary

| Service | Free Tier Amount | Duration |
|---------|-----------------|----------|
| S3 Storage | 5 GB | First 12 months |
| S3 GET Requests | 20,000 / month | First 12 months |
| S3 PUT Requests | 2,000 / month | First 12 months |
| CloudFront Data Transfer | 1 TB / month | Always free |
| CloudFront HTTP Requests | 10,000,000 / month | Always free |
| CloudFront Invalidations | 1,000 paths / month | Always free |
| ACM Public Certificate | Unlimited | Always free |
| Lambda Invocations | 1,000,000 / month | Always free |
| Lambda Compute | 400,000 GB-seconds / month | Always free |
| DynamoDB Storage | 25 GB | Always free |
| DynamoDB Read/Write (Provisioned mode only) | 25 WCU / 25 RCU | Always free — **does not apply to our on-demand table** |
| Cognito User Pool MAU | 10,000 / month (Essentials tier) | Always free |
| API Gateway HTTP API Requests | 1,000,000 / month | First 12 months only |

---

## Cost Optimization Notes

- **CloudFront invalidation**: `/*` invalidates all paths at once, counting as 1 path toward the 1,000 free limit. Current setup is optimal.
- **S3 versioning**: Disabled intentionally — versioning would accumulate old build files and increase storage costs.
- **GitHub Actions**: Public repos get unlimited free minutes. Keep the repo public to avoid charges.
- **Phase 05 tip**: Stop ECS tasks and RDS instances when not demoing to avoid continuous compute charges.

---

---

# コスト試算 — AWS Portfolio（日本語）

2026年時点の東京リージョン（ap-northeast-1）の料金に基づく。
想定トラフィック: **月間約1,000訪問（ポートフォリオ規模）**

---

## Phase 01 — 静的サイトホスティング

### 使用サービス

| サービス | 使用量 | 無料枠 | 月額試算 |
|---------|--------|--------|---------|
| S3 ストレージ | 約2MB（ビルドファイル） | 5GB / 12ヶ月 | **$0.00** |
| S3 リクエスト | 約500 PUT/月（CI/CDデプロイ） | 2,000 PUT / 12ヶ月 | **$0.00** |
| CloudFront 転送量 | 約0.5GB/月 | 1TB / 常時無料 | **$0.00** |
| CloudFront リクエスト | 約10,000回/月 | 1,000万回 / 常時無料 | **$0.00** |
| CloudFront Invalidation | 約10パス/月 | 1,000パス / 常時無料 | **$0.00** |
| IAM | — | 常時無料 | **$0.00** |
| GitHub Actions | 約5分/デプロイ × 10回 | 無制限（パブリックリポジトリ） | **$0.00** |

### Phase 01 合計

| シナリオ | 月額 | 年額 |
|---------|------|------|
| 無料枠内（最初の12ヶ月） | **$0.00** | **$0.00** |
| 無料枠終了後 | **約$0.01** | **約$0.12** |

> Phase 01 は実質無料。無料枠終了後のS3ストレージ: $0.025/GB × 0.002GB = 月額$0.00005。

---

## Phase 02 — カスタムドメイン + HTTPS（予定）

### 追加サービス

| サービス | 使用量 | 無料枠 | 月額試算 |
|---------|--------|--------|---------|
| ACM 証明書 | 1枚 | 常時無料（パブリック証明書） | **$0.00** |
| Route 53 ホストゾーン | 1ゾーン | なし | **$0.50** |
| Route 53 DNSクエリ | 約10,000回/月 | $0.50に100万クエリ含む | **$0.00** |

### Phase 02 追加コスト

| シナリオ | 月額 | 年額 |
|---------|------|------|
| Phase 01 比 追加分 | **$0.50** | **$6.00** |

> ポートフォリオ規模での唯一の実費はRoute 53ホストゾーン代のみ。

---

## Phase 03 — サーバーレスアプリ（2026-07-11 実機デプロイ済み）

### 追加サービス

| サービス | 使用量（ポートフォリオ規模の実測） | 無料枠 | 月額試算 |
|---------|--------|--------|---------|
| Cognito User Pool（Essentialsティア） | テストユーザー1名 | 10,000 MAU/月・常時無料 | **$0.00** |
| API Gateway（HTTP API） | 約100リクエスト/月 | 100万リクエスト/12ヶ月、以降$1.00/100万 | **$0.00** |
| Lambda（4関数） | 約400回呼び出し/月 | 100万リクエスト＋400,000 GB秒・常時無料 | **$0.00** |
| DynamoDB（オンデマンド）ストレージ | 1MB未満 | 25GB・常時無料 | **$0.00** |
| DynamoDB（オンデマンド）リクエスト | 約500 read + 200 write/月 | オンデマンドモードには無料枠なし（$0.25/100万read・$1.25/100万write、米国基準。東京はやや高め） | **$0.00**（$0.01未満） |

### Phase 03 追加コスト

| シナリオ | 月額 | 年額 |
|---------|------|------|
| 現在のポートフォリオ規模の使用量 | **約$0.00** | **約$0.00** |
| API Gateway無料枠終了後（12ヶ月後） | **約$0.01** | **約$0.12** |

> Phase 01/02と異なり、DynamoDBオンデマンドモードは**リクエスト課金に無料枠が無い**（無料なのはストレージ25GB分のみ）。ただしポートフォリオのデモ規模のトラフィックではリクエスト単価が実質ゼロに丸まる。今後実ユーザーのトラフィックが発生した場合、真っ先に注視すべきコスト項目はDynamoDBのリクエスト課金（API GatewayとLambdaの無料枠ははるかに大きい）。

---

## Phase 04–06 — コスト概算（予定）

| Phase | 追加主要サービス | 月額概算 |
|-------|---------------|---------|
| 04 オブザーバビリティ | CloudWatch Logs・X-Ray・SNS | 約$0.00〜$1.00 |
| 05 コンテナ | ECS Fargate・ALB・RDS | 約$30〜$80 |
| 06 DevOps | CodePipeline・CodeBuild | 約$1.00〜$5.00 |

> Phase 05（コンテナ）がコストの大きな転換点。FargateとRDSはゼロトラフィックでも常時課金されるため、デモ時以外は停止推奨。

---

## コスト最適化ポイント

- **CloudFront Invalidation**: `/*` で全パスを一括無効化しても「1パス」としてカウント。現在の設定は最適。
- **S3バージョニング**: 意図的に無効化。有効にすると古いビルドファイルが蓄積しストレージコストが増加する。
- **GitHub Actions**: パブリックリポジトリは無料枠が無制限。リポジトリを公開状態に保つことで課金を回避できる。
- **Phase 05 注意**: デモしない期間はECSタスクとRDSインスタンスを停止してコンピューティング課金を抑える。
