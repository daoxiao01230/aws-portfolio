resource "aws_route53_record" "site" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name    = aws_cloudfront_distribution.site.domain_name
    # CloudFront's fixed global hosted zone ID (not the account's hosted zone)
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
