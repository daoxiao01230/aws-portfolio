# ============================================================
# ACM 証明書（journal.daoxiao.org）
# Phase 2（aws-portfolio-02-custom-domain/infrastructure/terraform/acm.tf）と同じパターン。
# CloudFrontで使うACM証明書はリージョンに関わらずus-east-1で発行する必要がある
# （AWSのグローバル制約。providers.tfのaws.us_east_1エイリアスを使用）
# ============================================================
resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Project = var.project_name
  }

  # 証明書を更新する際、新しい証明書の発行完了を待ってから
  # 古い証明書を削除する（CloudFrontが証明書なしの状態になる瞬間を作らない）
  lifecycle {
    create_before_destroy = true
  }
}

# ACMのDNS検証用CNAMEレコードをRoute53に自動作成する
# （ACM証明書のドメイン所有権確認のため、AWS側が要求するレコード）
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

# DNS検証が完了する（ACMがCNAMEレコードを確認できる）まで
# terraform applyを待機させる。CloudFrontディストリビューションは
# この検証完了を待ってから証明書を利用する
resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
