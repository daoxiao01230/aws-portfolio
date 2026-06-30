# ============================================================
# Terraform 全リソース削除スクリプト（Phase 01）- PowerShell版
# 実行すると S3・CloudFront・OAC・BucketPolicy・IAM が全て削除される
# ============================================================
# 使い方（aws-portfolio-01-static-site\ から実行）:
#   .\scripts\destroy-terraform.ps1
#
# 前提条件:
#   - infrastructure\terraform\ で terraform apply 済みであること
#   - AWS CLIの認証情報が設定済みであること（aws configure）
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "  Terraform 全リソース削除（Phase 01）"
Write-Host "  対象: S3 + CloudFront + OAC + IAM"
Write-Host "========================================"
Write-Host ""

$confirm = Read-Host "本当に全リソースを削除しますか？ (yes と入力して確認)"
if ($confirm -ne "yes") {
    Write-Host "キャンセルしました。"
    exit 0
}

Write-Host ""
Write-Host ">>> terraform destroy を実行します..."
Set-Location infrastructure\terraform
terraform destroy

Write-Host ""
Write-Host "========================================"
Write-Host "  削除完了"
Write-Host "  全AWSリソースが削除されました"
Write-Host "========================================"
