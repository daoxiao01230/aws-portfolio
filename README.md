# AWS Portfolio — daoxiao

A progressive series of AWS projects demonstrating cloud architecture skills, from static hosting to enterprise-grade DevOps.

Each phase is an independently deployable product. Infrastructure is defined as code using both Terraform and CloudFormation.

---

## Portfolio Roadmap

| Phase | Project | Core Services | Status |
|-------|---------|---------------|--------|
| 01 | [Static Site Hosting](./aws-portfolio-01-static-site/) | S3, CloudFront, IAM, GitHub Actions | ✅ Complete |
| 02 | Custom Domain + HTTPS | ACM, Route 53 | 🔧 In Progress |
| 03 | Serverless Application | Cognito, API Gateway, Lambda, DynamoDB | 📋 Planned |
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
├── aws-portfolio-01-static-site/   # Phase 01
├── aws-portfolio-02-custom-domain/ # Phase 02 (coming soon)
└── .github/workflows/
    ├── deploy-01-static-site.yml   # triggers on Phase 01 changes only
    └── deploy-02-custom-domain.yml # triggers on Phase 02 changes only
```

---

## IaC Strategy

Every phase is implemented twice — once with **Terraform** and once with **CloudFormation** — to demonstrate proficiency with both tools.
