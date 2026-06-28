output "website_url" {
  description = "Custom domain URL"
  value       = "https://${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "certificate_arn" {
  description = "ACM certificate ARN (us-east-1)"
  value       = aws_acm_certificate.cert.arn
}
