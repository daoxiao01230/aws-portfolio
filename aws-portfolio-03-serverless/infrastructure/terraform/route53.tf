# ============================================================
# Route 53 Aレコード（エイリアス）
# journal.daoxiao.org へのアクセスをCloudFrontディストリビューションへ向ける。
# Phase 2が管理するdaoxiao.orgの既存ホストゾーンにレコードを1件追加するだけで、
# 新しいホストゾーンは作らない（$0.50/月の追加費用を避ける）
# ============================================================
resource "aws_route53_record" "frontend" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name = aws_cloudfront_distribution.frontend.domain_name
    # CloudFrontの固定グローバルホストゾーンID（このAWSアカウントのゾーンではない）
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
