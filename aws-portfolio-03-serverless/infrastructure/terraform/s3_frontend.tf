# ============================================================
# Phase 3 フロントエンド配信用 S3 バケット
# Phase 1（aws-portfolio-01-static-site/infrastructure/terraform/main.tf）と
# 同じ構成: プライベートバケット + CloudFront OAC 経由のみ許可
#
# 【Phase 1のバケットを流用しない理由】
# READMEの「各Phaseは独立してデプロイ・破棄可能」という方針を守るため。
# Phase 1のバケットにパスを分けて相乗りする案もあったが、
# 相乗りするとPhase 3を削除する際にPhase 1へ影響しないか毎回確認が必要になる。
# 別バケット・別ディストリビューションにしておけば、
# `terraform destroy` をPhase単位で安全に実行できる。
# ============================================================

# バケット名はAWSグローバルで一意である必要があるため、
# アカウントIDを付与して衝突を避ける（ランダムサフィックスより読みやすい）
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  bucket = "portfolio-03-serverless-frontend-${data.aws_caller_identity.current.account_id}"

  # terraform destroy 時にバケット内のファイルを自動削除してからバケットを削除する
  # 理由: 学習用ポートフォリオのため、一コマンドで全リソースを削除できるようにする
  force_destroy = true

  tags = {
    Project = var.project_name
  }

  # -------------------------------------------------------
  # 【設定しない項目】（Phase 1と同じ判断）
  # -------------------------------------------------------
  # website（S3静的ウェブサイトホスティング）: 使わない
  #   理由: CloudFrontをフロントに置くため不要。S3直接公開はHTTPS非対応。
  # versioning: バージョニング無効
  #   理由: ソースコードはGitで管理するため不要。ストレージコスト増加を避ける。
}

# ============================================================
# S3 パブリックアクセスブロック
# CloudFront OAC経由でのみアクセスを許可し、S3への直接パブリックアクセスは
# 完全に遮断する（Phase 1と同一設計）
# ============================================================
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# S3バケットポリシー
# このバケット専用のCloudFrontディストリビューションからのみ
# s3:GetObject を許可する（Condition の AWS:SourceArn で紐付け）
# ============================================================
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
        # 読み取り専用。書き込み(PutObject)はデプロイ時に手動/CIで行う想定
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            # 他のAWSアカウント・他のCloudFrontディストリビューションからの
            # アクセスを防ぐため、このディストリビューションのARNに限定する
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}
