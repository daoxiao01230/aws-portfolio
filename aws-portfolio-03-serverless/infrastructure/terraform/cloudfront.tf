# ============================================================
# CloudFront Origin Access Control（OAC）
# CloudFrontがプライベートS3にアクセスするための認証メカニズム。
# Phase 1（aws-portfolio-01-static-site/infrastructure/terraform/main.tf）と同じ設定
# ============================================================
resource "aws_cloudfront_origin_access_control" "frontend" {
  name        = "${aws_s3_bucket.frontend.bucket}-oac"
  description = "OAC for ${aws_s3_bucket.frontend.bucket}"

  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ============================================================
# CloudFront ディストリビューション
# journal.daoxiao.org 宛のリクエストをS3のReactビルド成果物に配信する。
# Phase 1とは別バケット・別ディストリビューションとして独立させている
# （理由はs3_frontend.tf冒頭のコメント参照）
# ============================================================
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  http_version        = "http2"

  # カスタムドメインでのアクセスを許可する
  # 対応するACM証明書がviewer_certificateに必要（acm.tf参照）
  aliases = [var.domain_name]

  origin {
    # S3のリージョナルドメインを使用（グローバルドメインはリダイレクト問題があるため非推奨）
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id = "S3-${aws_s3_bucket.frontend.bucket}"

    # 静的ファイル配信のみなのでGET/HEADで十分。
    # POST/PUT/DELETEはAPI Gateway（別ドメイン）宛のため、CloudFrontを経由しない
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # デプロイ後は `aws cloudfront create-invalidation --paths "/*"` を
    # 実行しないと、この default_ttl(1時間) の間は古いファイルが配信され続ける
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # 現状このReactアプリはクライアントサイドルーティングを使っていない
  # （認証状態によるコンポーネント切り替えのみ、URLパスは常に "/"）ため
  # 実際には403/404が発生する経路は無いが、将来react-router等を
  # 導入した際に無変更で動くよう、Phase 1と同じフォールバックを設定しておく
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

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.frontend.certificate_arn
    # "sni-only" = 追加コストなしで全モダンブラウザに対応
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Project = var.project_name
  }
}
