# Phase 1 で CloudFormation が作成した CF distribution を Terraform の管理下に移す
# import ブロックは Terraform 1.5+ で使用可能
# 実行前に Phase 1 Terraform の output から以下の値を取得すること:
#   cd aws-portfolio-01-static-site/infrastructure/terraform
#   terraform output cloudfront_distribution_id
#   terraform output cloudfront_oac_id
#   terraform output s3_bucket_name

import {
  to = aws_cloudfront_distribution.site
  id = var.cloudfront_distribution_id
}

data "aws_s3_bucket" "phase1" {
  bucket = var.bucket_name
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  http_version        = "http2"

  # Phase 2 追加: カスタムドメイン
  aliases = [var.domain_name]

  origin {
    domain_name              = data.aws_s3_bucket.phase1.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    # Phase 1 の OAC をそのまま参照（Phase 1 の tfstate が管理し続ける）
    origin_access_control_id = var.oac_id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Phase 2 変更: CloudFront デフォルト証明書 → ACM 証明書
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Project = var.project
  }
}
