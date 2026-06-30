# ============================================================
# CloudFormation 全リソース削除スクリプト（Phase 01）- PowerShell版
# 対象スタック（削除順序）:
#   1. portfolio-01-iam        （IAMユーザー）
#   2. portfolio-01-cloudfront （CloudFront + OAC + BucketPolicy）
#   3. portfolio-01-s3         （S3バケット）
# ============================================================
# 使い方:
#   .\scripts\destroy-cloudformation.ps1 -BucketName <バケット名>
#
#   例:
#   .\scripts\destroy-cloudformation.ps1 -BucketName portfolio-01-gratitude-2026-v2
#
# 前提条件:
#   - AWS CLIの認証情報が設定済みであること（aws configure）
#   - 3つのスタックが存在すること
# ============================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$BucketName
)

# エラー発生時に即座に停止
$ErrorActionPreference = "Stop"

$STACK_IAM = "portfolio-01-iam"
$STACK_CF  = "portfolio-01-cloudfront"
$STACK_S3  = "portfolio-01-s3"

Write-Host "========================================"
Write-Host "  CloudFormation 全リソース削除（Phase 01）"
Write-Host "  バケット名 : $BucketName"
Write-Host "  削除対象  :"
Write-Host "    1. $STACK_IAM"
Write-Host "    2. $STACK_CF"
Write-Host "    3. $STACK_S3"
Write-Host "========================================"
Write-Host ""
Write-Host "  注意: 実行するとサイトがオフラインになります"
Write-Host ""

$confirm = Read-Host "本当に全リソースを削除しますか？ (yes と入力して確認)"
if ($confirm -ne "yes") {
    Write-Host "キャンセルしました。"
    exit 0
}

# ステップ1: IAMスタック削除
Write-Host ""
Write-Host ">>> [1/4] IAMスタックを削除しています... ($STACK_IAM)"
aws cloudformation delete-stack --stack-name $STACK_IAM
aws cloudformation wait stack-delete-complete --stack-name $STACK_IAM
Write-Host "    完了"

# ステップ2: CloudFrontスタック削除
Write-Host ""
Write-Host ">>> [2/4] CloudFrontスタックを削除しています... ($STACK_CF)"
aws cloudformation delete-stack --stack-name $STACK_CF
aws cloudformation wait stack-delete-complete --stack-name $STACK_CF
Write-Host "    完了"

# ステップ3: S3バケットを空にする
Write-Host ""
Write-Host ">>> [3/4] S3バケットのファイルを削除しています... ($BucketName)"
aws s3 rm s3://$BucketName --recursive
Write-Host "    完了"

# ステップ4: S3スタック削除
Write-Host ""
Write-Host ">>> [4/4] S3スタックを削除しています... ($STACK_S3)"
aws cloudformation delete-stack --stack-name $STACK_S3
aws cloudformation wait stack-delete-complete --stack-name $STACK_S3
Write-Host "    完了"

Write-Host ""
Write-Host "========================================"
Write-Host "  削除完了"
Write-Host "  全AWSリソースが削除されました"
Write-Host "========================================"
