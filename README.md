# Portfolio 01 — Static Site Hosting

React app deployed to AWS with S3 + CloudFront, automated via GitHub Actions, with infrastructure defined as code using both Terraform and CloudFormation.

## Architecture

```
GitHub (push to main)
        │
GitHub Actions
        │
   npm run build
        │
   aws s3 sync
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
| GitHub Actions | CI/CD — auto deploy on push to main |
| CloudFormation | Infrastructure as Code (option A) |
| Terraform | Infrastructure as Code (option B) |

## Deploy Infrastructure

### Option A: Terraform

```bash
cd terraform
terraform init
terraform apply -var="bucket_name=your-bucket-name"
```

Outputs: `website_url`, `cloudfront_distribution_id`, `s3_bucket_name`

### Option B: CloudFormation

```bash
aws cloudformation deploy \
  --template-file cloudformation/template.yaml \
  --stack-name portfolio-01-static-site \
  --parameter-overrides BucketName=your-bucket-name
```

## Setup GitHub Actions CI/CD

Add these secrets in GitHub → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | e.g. `us-east-1` |
| `S3_BUCKET_NAME` | From Terraform/CFN output |
| `CLOUDFRONT_DISTRIBUTION_ID` | From Terraform/CFN output |

After setup, every push to `main` automatically builds and deploys.

## Local Development

```bash
npm install
npm start
```

## Key Decisions

- S3 bucket is **private** — CloudFront accesses it via Origin Access Control (OAC), not public ACL
- 403/404 errors redirect to `index.html` to support client-side routing
- Both Terraform and CloudFormation produce identical infrastructure
