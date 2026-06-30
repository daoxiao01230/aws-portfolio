#!/bin/bash
# ============================================================
# Terraform 全リソース削除スクリプト（Phase 01）
# 実行すると S3・CloudFront・OAC・BucketPolicy・IAM が全て削除される
# ============================================================
# 使い方（aws-portfolio-01-static-site/ から実行）:
#   bash scripts/destroy-terraform.sh
#
# 前提条件:
#   - infrastructure/terraform/ で terraform apply 済みであること
#   - AWS CLIの認証情報が設定済みであること（aws configure）
# ============================================================

set -e

echo "========================================"
echo "  Terraform 全リソース削除（Phase 01）"
echo "  対象: S3 + CloudFront + OAC + IAM"
echo "========================================"
echo ""

read -p "本当に全リソースを削除しますか？ (yes と入力して確認): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "キャンセルしました。"
  exit 0
fi

echo ""
echo ">>> terraform destroy を実行します..."
cd infrastructure/terraform
terraform destroy

echo ""
echo "========================================"
echo "  削除完了"
echo "  全AWSリソースが削除されました"
echo "========================================"
