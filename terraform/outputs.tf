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
