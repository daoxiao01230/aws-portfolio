# ============================================================
# Phase 3 フロントエンド配信用 S3 バケット
# Phase 1と同じ構成: プライベートバケット + CloudFront OAC 経由のみ許可
# ============================================================
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  # バケット名はAWSグローバルで一意である必要があるためアカウントIDを付与
  bucket = "portfolio-03-serverless-frontend-${data.aws_caller_identity.current.account_id}"

  # 学習用ポートフォリオのため、destroy時に中身ごと削除できるようにする
  force_destroy = true

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}
