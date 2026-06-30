output "website_url" {
  description = "CloudFront URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID (use in GitHub Actions secret)"
  value       = aws_cloudfront_distribution.website.id
}

output "s3_bucket_name" {
  description = "S3 Bucket Name (use in GitHub Actions secret)"
  value       = aws_s3_bucket.website.id
}

output "cloudfront_oac_id" {
  description = "CloudFront OAC ID (used by Phase 2 Terraform import)"
  value       = aws_cloudfront_origin_access_control.website.id
}

output "github_actions_access_key_id" {
  description = "IAM access key ID — set as GitHub Secret: AWS_ACCESS_KEY_ID"
  value       = aws_iam_access_key.github_actions.id
}

output "github_actions_secret_access_key" {
  description = "IAM secret access key — set as GitHub Secret: AWS_SECRET_ACCESS_KEY"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}
