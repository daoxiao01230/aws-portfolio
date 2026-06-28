variable "aws_region" {
  description = "Primary AWS region"
  default     = "ap-northeast-1"
}

variable "domain_name" {
  description = "Custom domain for the portfolio site"
  default     = "gratitude.daoxiao.org"
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for daoxiao.org"
  default     = "Z06510601ASWSVLJJY29P"
}

# --- Phase 1 Terraform outputs (pass via terraform.tfvars or -var flag) ---

variable "cloudfront_distribution_id" {
  description = "Phase 1 CF distribution ID — from: terraform output cloudfront_distribution_id"
  type        = string
}

variable "bucket_name" {
  description = "Phase 1 S3 bucket name — from: terraform output s3_bucket_name"
  type        = string
}

variable "oac_id" {
  description = "Phase 1 OAC ID — from: terraform output cloudfront_oac_id"
  type        = string
}

variable "project" {
  description = "Project tag value"
  default     = "aws-portfolio-01-static-site"
}
