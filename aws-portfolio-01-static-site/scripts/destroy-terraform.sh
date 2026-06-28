#!/bin/bash
# ============================================================
# Terraform 全リソース削除スクリプト
# 実行すると S3・CloudFront・OAC・バケットポリシーが全て削除される
# ============================================================
# 使い方:
#   bash scripts/destroy-terraform.sh
#
# 前提条件:
#   - terraform/ ディレクトリで terraform apply 済みであること
#   - AWS CLIの認証情報が設定済みであること（aws configure）
#   - terraform.tfvars または -var で bucket_name が指定できること
# ============================================================

set -e  # エラー発生時に即座に停止

echo "========================================"
echo "  Terraform 全リソース削除"
echo "  対象: S3 + CloudFront + OAC"
echo "========================================"
echo ""

# 確認プロンプト（誤操作防止）
read -p "本当に全リソースを削除しますか？ (yes と入力して確認): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "キャンセルしました。"
  exit 0
fi

echo ""
echo ">>> terraform destroy を実行します..."
cd terraform
terraform destroy

echo ""
echo "========================================"
echo "  削除完了"
echo "  全AWSリソースが削除されました"
echo "========================================"
