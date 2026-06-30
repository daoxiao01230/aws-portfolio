#!/bin/bash
# ============================================================
# CloudFormation 全リソース削除スクリプト（Phase 01）
# 対象スタック（削除順序）:
#   1. portfolio-01-iam        （IAMユーザー）
#   2. portfolio-01-cloudfront （CloudFront + OAC + BucketPolicy）
#   3. portfolio-01-s3         （S3バケット）
# ============================================================
# 使い方:
#   bash scripts/destroy-cloudformation.sh <バケット名>
#
#   例:
#   bash scripts/destroy-cloudformation.sh portfolio-01-gratitude-2026-v2
#
# 前提条件:
#   - AWS CLIの認証情報が設定済みであること（aws configure）
#   - 3つのスタックが存在すること
# ============================================================
# 削除順序の理由:
#   portfolio-01-cloudfront は portfolio-01-s3 の BucketPolicy を持つため、
#   S3スタックより先に削除する必要がある。
#   IAMスタックは依存関係なしのため最初に削除。
# ============================================================

set -e

BUCKET_NAME=${1}
STACK_IAM="portfolio-01-iam"
STACK_CF="portfolio-01-cloudfront"
STACK_S3="portfolio-01-s3"

if [ -z "$BUCKET_NAME" ]; then
  echo "エラー: バケット名を引数で指定してください"
  echo "使い方: bash scripts/destroy-cloudformation.sh <バケット名>"
  echo "例:     bash scripts/destroy-cloudformation.sh portfolio-01-gratitude-2026-v2"
  exit 1
fi

echo "========================================"
echo "  CloudFormation 全リソース削除（Phase 01）"
echo "  バケット名 : $BUCKET_NAME"
echo "  削除対象  :"
echo "    1. $STACK_IAM"
echo "    2. $STACK_CF"
echo "    3. $STACK_S3"
echo "========================================"
echo ""
echo "  注意: 実行するとサイトがオフラインになります"
echo ""

read -p "本当に全リソースを削除しますか？ (yes と入力して確認): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "キャンセルしました。"
  exit 0
fi

# ステップ1: IAMスタック削除
echo ""
echo ">>> [1/4] IAMスタックを削除しています... ($STACK_IAM)"
aws cloudformation delete-stack --stack-name $STACK_IAM
aws cloudformation wait stack-delete-complete --stack-name $STACK_IAM
echo "    完了"

# ステップ2: CloudFrontスタック削除（BucketPolicyも削除される）
echo ""
echo ">>> [2/4] CloudFrontスタックを削除しています... ($STACK_CF)"
aws cloudformation delete-stack --stack-name $STACK_CF
aws cloudformation wait stack-delete-complete --stack-name $STACK_CF
echo "    完了"

# ステップ3: S3バケットを空にする
# 理由: CloudFormationはバケットに中身があると削除できない
echo ""
echo ">>> [3/4] S3バケットのファイルを削除しています... ($BUCKET_NAME)"
aws s3 rm s3://$BUCKET_NAME --recursive
echo "    完了"

# ステップ4: S3スタック削除
echo ""
echo ">>> [4/4] S3スタックを削除しています... ($STACK_S3)"
aws cloudformation delete-stack --stack-name $STACK_S3
aws cloudformation wait stack-delete-complete --stack-name $STACK_S3
echo "    完了"

echo ""
echo "========================================"
echo "  削除完了"
echo "  全AWSリソースが削除されました"
echo "========================================"
