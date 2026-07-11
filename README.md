# AWS Portfolio — daoxiao

A progressive series of AWS projects demonstrating cloud architecture skills, from static hosting to enterprise-grade DevOps.

Each phase is an independently deployable product. Infrastructure is defined as code using both Terraform and CloudFormation.

---

## Portfolio Roadmap

| Phase | Project | Core Services | Status |
|-------|---------|---------------|--------|
| 01 | [Static Site Hosting](./aws-portfolio-01-static-site/) | S3, CloudFront, IAM, GitHub Actions | ✅ [Live](https://d3ihmqzooh3cn3.cloudfront.net/) |
| 02 | [Custom Domain + HTTPS](./aws-portfolio-02-custom-domain/) | ACM, Route 53 | ✅ [Live](https://gratitude.daoxiao.org/) |
| 03 | [Serverless Application](./aws-portfolio-03-serverless/) | Cognito, API Gateway, Lambda, DynamoDB | 🚧 In Progress |
| 04 | Observability | CloudWatch, X-Ray, SNS | 📋 Planned |
| 05 | Containers | ECS Fargate, ALB, RDS | 📋 Planned |
| 06 | Enterprise DevOps | CodePipeline, Terraform, GitHub Actions | 📋 Planned |

---

## Architecture Evolution

```
Phase 01           Phase 02           Phase 03
S3 + CloudFront → + Route53/ACM   → + Cognito/Lambda/DynamoDB
(Static)           (Custom Domain)    (Serverless)
```

---

## Repository Structure

```
aws-portfolio/
├── docs/                           # Portfolio-wide documentation
│   └── Cost-Estimation.md         # AWS cost breakdown across all phases
├── aws-portfolio-01-static-site/   # Phase 01
│   └── docs/                      # Phase 01 specific docs
├── aws-portfolio-02-custom-domain/ # Phase 02 — ✅ live
│   └── docs/troubleshooting.md    # DNS clientHold investigation (RDAP-based diagnosis)
├── aws-portfolio-03-serverless/    # Phase 03 — 🚧 in progress
│   ├── infrastructure/terraform/  # Cognito, DynamoDB, Lambda, API Gateway (HTTP API + JWT authorizer)
│   ├── src/lambda/                # Python 3.12 handlers (create/list/update/delete entry)
│   └── react/                     # Login/signup + CRUD UI (Cognito + fetch, build verified)
└── .github/workflows/
    ├── deploy-01-static-site.yml   # triggers on Phase 01 changes only
    ├── deploy-02-custom-domain.yml # triggers on Phase 02 changes only
    └── deploy-03-serverless.yml    # triggers on Phase 03 Lambda code changes only
```

---

## IaC Strategy

Phase 01 is implemented twice — once with **Terraform** and once with **CloudFormation** — to demonstrate proficiency with both tools. Phase 02 was originally planned the same way, but its CloudFormation path depended on updating Phase 01's CloudFormation stack; once that stack was deleted during Phase 01's Terraform migration, Phase 02 was implemented in Terraform only (using an `import` block to adopt Phase 01's existing CloudFront distribution). The unused CloudFormation templates are kept in `aws-portfolio-02-custom-domain/infrastructure/cloudformation/` for reference — see that phase's README for details.

---

---

# AWS Portfolio — daoxiao（日本語）

AWS のクラウドアーキテクチャスキルを段階的に示すポートフォリオ。静的ホスティングからエンタープライズ DevOps まで、6 フェーズで構成。

各フェーズは独立してデプロイ可能なプロダクトとして設計。インフラは Terraform と CloudFormation の両方でコード化している。

---

## ポートフォリオ ロードマップ

| Phase | プロジェクト | 主要サービス | ステータス |
|-------|------------|------------|----------|
| 01 | [静的サイトホスティング](./aws-portfolio-01-static-site/) | S3, CloudFront, IAM, GitHub Actions | ✅ [公開中](https://d3ihmqzooh3cn3.cloudfront.net/) |
| 02 | [カスタムドメイン + HTTPS](./aws-portfolio-02-custom-domain/) | ACM, Route 53 | ✅ [公開中](https://gratitude.daoxiao.org/) |
| 03 | [サーバーレスアプリ](./aws-portfolio-03-serverless/) | Cognito, API Gateway, Lambda, DynamoDB | 🚧 進行中 |
| 04 | オブザーバビリティ | CloudWatch, X-Ray, SNS | 📋 予定 |
| 05 | コンテナ | ECS Fargate, ALB, RDS | 📋 予定 |
| 06 | エンタープライズ DevOps | CodePipeline, Terraform, GitHub Actions | 📋 予定 |

---

## アーキテクチャの進化

```
Phase 01           Phase 02               Phase 03
S3 + CloudFront → + Route53/ACM       → + Cognito/Lambda/DynamoDB
（静的配信）        （カスタムドメイン）    （サーバーレス）
```

---

## リポジトリ構造

```
aws-portfolio/
├── docs/                           # ポートフォリオ全体の共通ドキュメント
│   └── Cost-Estimation.md         # 全Phase の AWS コスト試算
├── aws-portfolio-01-static-site/   # Phase 01
│   └── docs/                      # Phase 01 専用ドキュメント
├── aws-portfolio-02-custom-domain/ # Phase 02 — ✅ 公開中
│   └── docs/troubleshooting.md    # DNS clientHold調査記録（RDAPによる診断）
├── aws-portfolio-03-serverless/    # Phase 03 — 🚧 進行中
│   ├── infrastructure/terraform/  # Cognito, DynamoDB, Lambda, API Gateway (HTTP API + JWT authorizer)
│   ├── src/lambda/                # Python 3.12 ハンドラー（日記のCRUD）
│   └── react/                     # ログイン/サインアップ + CRUD UI（Cognito + fetch、ビルド確認済み）
└── .github/workflows/
    ├── deploy-01-static-site.yml   # Phase 01 の変更時のみ発火
    ├── deploy-02-custom-domain.yml # Phase 02 の変更時のみ発火
    └── deploy-03-serverless.yml    # Phase 03 のLambdaコード変更時のみ発火
```

---

## IaC 方針

Phase 01 のインフラは **Terraform** と **CloudFormation** の両方で実装し、両ツールへの習熟を示している。Phase 02 も当初は同様の二重実装を計画していたが、そのCloudFormation経路はPhase 01のCloudFormationスタックを更新する設計だったため、Phase 01がTerraformへ移行しそのスタックが削除された時点で前提が崩れた。そのためPhase 02はTerraformのみで実装し（`import`ブロックでPhase 01の既存CloudFrontディストリビューションを引き継ぐ方式）、未使用のCloudFormationテンプレートは`aws-portfolio-02-custom-domain/infrastructure/cloudformation/`に参考として残している。詳細は当該フェーズのREADMEを参照。
