# ============================================================
# Portfolio 01 - 静的サイトホスティング
# 構成: S3（プライベートバケット）+ CloudFront（OAC経由）
# ============================================================


# ============================================================
# S3バケット
# 静的ファイル（HTML/CSS/JS/画像）を保存するストレージ
# ============================================================
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  # バケット名はAWSグローバルで一意である必要がある
  # 例: "portfolio-01-gratitude-journal-20240101"

  # terraform destroy 時にバケット内のファイルを自動削除してからバケットを削除する
  # false（デフォルト）にすると中身があるバケットの削除はエラーになる
  # 理由: ポートフォリオ学習用のため、一コマンドで全リソースを削除できるようにする
  force_destroy = true

  tags = {
    Project = "aws-portfolio-01-static-site"
  }

  # -------------------------------------------------------
  # 【設定しない項目】
  # -------------------------------------------------------
  #
  # website（S3静的ウェブサイトホスティング）: 使わない
  #   理由: CloudFrontをフロントに置くため不要。
  #         S3直接公開はHTTPS非対応・カスタムドメインが複雑になる。
  #
  # versioning: バージョニング無効
  #   理由: ソースコードはGitで管理するため不要。
  #         有効にするとストレージコストが増加する。
  #
  # lifecycle_rule: ライフサイクルルール設定なし
  #   理由: 静的ファイルは常時必要。自動削除・移行は不要。
  #
  # replication_configuration: レプリケーション設定なし
  #   理由: CloudFrontがグローバルCDNとして機能するため、
  #         マルチリージョンレプリケーションは不要。
  #
  # logging: アクセスログ設定なし
  #   理由: CloudFrontのアクセスログで代替可能。
  #         Phase 4（Observability）で追加予定。
  #
  # cors_rule: CORS設定なし
  #   理由: CloudFront経由でのアクセスのみ想定。
  #         APIは存在しない（Phase 3で追加）。
  #
  # server_side_encryption_configuration: 暗号化を明示しない
  #   理由: 2023年以降、AWSはSSE-S3をデフォルトで自動有効化済み。
  #         静的ファイルにはSSE-S3で十分。KMSは不要。
}


# ============================================================
# S3 パブリックアクセスブロック
# バケットへの直接パブリックアクセスを完全に遮断する
# ============================================================
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  # パブリックACLの新規付与をブロック
  block_public_acls = true

  # パブリックACLを許可するバケットポリシーをブロック
  block_public_policy = true

  # 既存のパブリックACLを無視（実質的に無効化）
  ignore_public_acls = true

  # パブリックバケットポリシーによる外部アクセスを制限
  restrict_public_buckets = true

  # 4項目すべてtrueにする理由:
  # CloudFront OAC経由でのみアクセスを許可するため、
  # S3への直接パブリックアクセスは完全に不要。
  # AWSセキュリティのベストプラクティスに準拠。
}


# ============================================================
# CloudFront Origin Access Control（OAC）
# CloudFrontがプライベートS3にアクセスするための認証メカニズム
# OAI（Origin Access Identity）の後継。新規構築はOACを使う。
# ============================================================
resource "aws_cloudfront_origin_access_control" "website" {
  name        = "${var.bucket_name}-oac"
  description = "OAC for ${var.bucket_name}"

  # オリジンの種類
  # "s3"            = S3バケット（今回の設定）
  # "mediastore"    = AWS Elemental MediaStore
  # "mediapackagev2"= AWS Elemental MediaPackage v2
  # "lambda"        = Lambda Function URL
  origin_access_control_origin_type = "s3"

  # リクエストへの署名方法
  # "always"      = 常に署名する（推奨・今回の設定）
  # "never"       = 署名しない（パブリックオリジン向け）
  # "no-override" = オリジンが署名を要求する場合のみ署名
  signing_behavior = "always"

  # 署名プロトコル
  # "sigv4" = AWS Signature Version 4（現在の標準・唯一の選択肢）
  signing_protocol = "sigv4"
}


# ============================================================
# CloudFront ディストリビューション
# グローバルCDN。S3コンテンツをHTTPS経由で世界中に配信する。
# ============================================================
resource "aws_cloudfront_distribution" "website" {

  # ----------------------------------------------------------
  # オリジン設定
  # ----------------------------------------------------------
  origin {
    # S3のリージョナルドメインを使用
    # 理由: グローバルドメイン（s3.amazonaws.com）は
    #       リダイレクト問題が発生することがあるため、
    #       リージョナルドメインが推奨される。
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name

    # オリジンを識別するID（キャッシュ動作と紐付けるために使用）
    origin_id = "S3-${var.bucket_name}"

    # OACを紐付ける（S3へのアクセス認証）
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id

    # -------------------------------------------------------
    # 【設定しない項目】
    # -------------------------------------------------------
    #
    # custom_origin_config: カスタムオリジン設定
    #   理由: S3オリジンには不要（EC2/ALB向けの設定）
    #
    # origin_shield: オリジンシールド（追加キャッシュレイヤー）
    #   理由: 静的サイトでは過剰。オリジンへのリクエスト数削減が
    #         必要な大規模サイトで有効。追加コストが発生する。
  }

  # ディストリビューションを有効化
  enabled = true

  # IPv6対応を有効化
  # 理由: 追加コストなし。モバイル環境ではIPv6が主流になっている。
  is_ipv6_enabled = true

  # デフォルトルートオブジェクト
  # "/" へのアクセス時に返すファイル
  default_root_object = "index.html"

  # HTTPバージョン
  # "http2"       = HTTP/2のみ（今回の設定）
  # "http2and3"   = HTTP/2 + HTTP/3（QUIC対応）
  # 理由: http2で現代的なブラウザをすべてカバーできる。
  #       http2and3はよりパフォーマンスが高いが、
  #       Phase 1では http2 で十分。
  http_version = "http2"

  # -------------------------------------------------------
  # 【設定しない項目】
  # -------------------------------------------------------
  #
  # aliases: カスタムドメイン（例: gratitude.daoxiao.org）
  #   理由: Phase 1はCloudFrontデフォルトドメインを使用。
  #         Phase 2でACM証明書と合わせて設定する。
  #
  # price_class: 配信リージョンの範囲
  #   デフォルト = PriceClass_All（全世界・今回の設定）
  #   PriceClass_100 = 北米・欧州のみ（低コスト）
  #   PriceClass_200 = 北米・欧州・アジア（中コスト）
  #   理由: ポートフォリオは全世界に公開したい。
  #         コスト削減が必要な場合はPriceClass_100に変更可。
  #
  # web_acl_id: AWS WAF（Webアプリケーションファイアウォール）
  #   理由: 静的サイトには過剰。APIを追加するPhase 3以降で検討。
  #
  # logging_config: アクセスログ
  #   理由: Phase 4（Observability）で追加予定。
  #         ログ保存用S3バケットが別途必要。
  #
  # comment: ディストリビューションの説明
  #   理由: 任意項目。複数ディストリビューションがある場合に有用。


  # ----------------------------------------------------------
  # デフォルトキャッシュ動作
  # ----------------------------------------------------------
  default_cache_behavior {
    target_origin_id = "S3-${var.bucket_name}"

    # 許可するHTTPメソッド
    # ["GET", "HEAD"]           = 読み取りのみ（今回の設定）
    # ["GET", "HEAD", "OPTIONS"]= OPTIONSも許可（CORS対応時）
    # ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"] = 全メソッド
    # 理由: 静的サイトはGET/HEADのみ必要。
    #       POST/PUT/DELETEはバックエンドAPIが必要（Phase 3以降）。
    allowed_methods = ["GET", "HEAD"]

    # キャッシュするHTTPメソッド
    # GET/HEADのレスポンスのみキャッシュ
    # OPTIONSはキャッシュ可能だが、今回はOPTIONS自体が不要
    cached_methods = ["GET", "HEAD"]

    # ビューワープロトコルポリシー
    # "redirect-to-https" = HTTPアクセスをHTTPSに自動リダイレクト（今回の設定・推奨）
    # "https-only"        = HTTPアクセスを403エラーで拒否
    # "allow-all"         = HTTP/HTTPS両方許可（非推奨・セキュリティリスク）
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      # クエリ文字列をオリジンに転送しない
      # 理由: 静的ファイルはURLパラメータを処理しない。
      #       転送するとキャッシュキーが増加しヒット率が下がる。
      query_string = false

      cookies {
        # Cookieの転送設定
        # "none"      = 転送しない（今回の設定）
        # "all"       = すべて転送（動的コンテンツ・ログイン機能向け）
        # "whitelist" = 指定したCookieのみ転送
        # 理由: 静的ファイルはCookieを必要としない。
        #       転送するとキャッシュヒット率が下がる。
        forward = "none"
      }
    }

    # TTL（Time To Live）: CloudFrontキャッシュの有効期間（秒）
    # min_ttl     =     0: Cache-Controlヘッダーで0秒指定を許可（キャッシュ無効化可能）
    # default_ttl =  3600: Cache-Controlヘッダーがない場合のデフォルト（1時間）
    # max_ttl     = 86400: キャッシュの最大保持時間（1日）
    #
    # 注意: デプロイ後はGitHub ActionsでCloudFront Invalidation（/*）を
    #       実行しないと古いキャッシュが配信され続ける
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    # compress: gzip/Brotli圧縮（デフォルトtrue・明示的に書かなくても有効）
    # 理由: JS/CSS/HTMLを圧縮してロード時間を短縮。追加コストなし。
    compress = true
  }


  # ----------------------------------------------------------
  # カスタムエラーレスポンス
  # React Router（クライアントサイドルーティング）対応
  # ----------------------------------------------------------
  # 問題: S3はOACで保護されているため、存在しないパス（例: /about）に
  #       アクセスすると403または404を返す。
  # 解決: CloudFrontでエラーをキャッチし、index.htmlを返す。
  #       Reactがクライアント側でルーティングを処理する。

  # S3がファイルへのアクセスを拒否した場合（OAC保護により403）
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  # S3にファイルが存在しない場合（404）
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }


  # ----------------------------------------------------------
  # 地理的制限
  # ----------------------------------------------------------
  restrictions {
    geo_restriction {
      # "none"      = 制限なし・全世界からアクセス可能（今回の設定）
      # "whitelist" = 許可する国を指定（例: ["JP", "US"]）
      # "blacklist" = ブロックする国を指定
      # 理由: ポートフォリオは全世界の採用担当者に見せたい。
      restriction_type = "none"
    }
  }


  # ----------------------------------------------------------
  # SSL/TLS証明書
  # ----------------------------------------------------------
  viewer_certificate {
    # CloudFrontのデフォルト証明書を使用（*.cloudfront.net ドメイン）
    cloudfront_default_certificate = true

    # 理由: Phase 1はカスタムドメインなし。
    #       Phase 2でカスタムドメインを追加する際は以下に切り替える:
    #
    # acm_certificate_arn      = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/xxxx"
    # ssl_support_method       = "sni-only"  # 全クライアント対応・追加コストなし
    # minimum_protocol_version = "TLSv1.2_2021"  # 現在の推奨最低バージョン
    # cloudfront_default_certificate = false
    #
    # 注意: ACM証明書はus-east-1リージョンで作成する必要がある（CloudFrontの要件）
  }

  tags = {
    Project = "aws-portfolio-01-static-site"
  }
}


# ============================================================
# IAM ユーザー（GitHub Actions 専用）
# GitHub Actions から S3 デプロイ + CloudFront Invalidation を行うユーザー
# ============================================================
resource "aws_iam_user" "github_actions" {
  name = "github-actions-portfolio-01"

  tags = {
    Project = "aws-portfolio-01-static-site"
  }
}

resource "aws_iam_user_policy" "github_actions" {
  name = "portfolio-01-deploy-policy"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Deploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      },
      {
        Sid      = "CloudFrontInvalidation"
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = aws_cloudfront_distribution.website.arn
      }
    ]
  })
}

resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}


# ============================================================
# S3バケットポリシー
# CloudFrontからのみS3へのアクセスを許可する
# ============================================================
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          # cloudfront.amazonaws.com = CloudFrontサービスプリンシパル
          # 特定のIAMユーザー/ロールではなく、CloudFrontサービス自体に許可
          Service = "cloudfront.amazonaws.com"
        }
        # s3:GetObject のみ許可（読み取り専用）
        # s3:PutObject / s3:DeleteObject / s3:ListBucket は許可しない
        # 理由: CloudFrontはファイルを読むだけでよい。
        #       書き込み権限はGitHub Actions（IAMユーザー）が持つ。
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            # このCloudFrontディストリビューションからのリクエストのみ許可
            # 理由: 他のAWSアカウントのCloudFrontからのアクセスを防ぐ
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}
