#!/bin/bash
# ============================================================
# CloudFormation 全リソース削除スクリプト
# 実行すると S3・CloudFront・OAC・バケットポリシーが全て削除される
# ============================================================
# 使い方:
#   bash scripts/destroy-cloudformation.sh <バケット名> <スタック名>
#
#   例:
#   bash scripts/destroy-cloudformation.sh \
#     portfolio-01-gratitude-journal-20240101 \
#     portfolio-01-static-site
#
# 前提条件:
#   - AWS CLIの認証情報が設定済みであること（aws configure）
#   - 対象スタックが存在すること
# ============================================================
# CloudFormationがS3バケットを削除できない理由:
#   CloudFormationはバケットに中身があると削除できない仕様。
#   このスクリプトでは先にS3を空にしてからスタックを削除する。
# ============================================================

set -e  # エラー発生時に即座に停止

# 引数チェック
BUCKET_NAME=${1}
STACK_NAME=${2:-"portfolio-01-static-site"}  # デフォルトスタック名

if [ -z "$BUCKET_NAME" ]; then
  echo "エラー: バケット名を引数で指定してください"
  echo "使い方: bash scripts/destroy-cloudformation.sh <バケット名> [スタック名]"
  exit 1
fi

echo "========================================"
echo "  CloudFormation 全リソース削除"
echo "  バケット名 : $BUCKET_NAME"
echo "  スタック名 : $STACK_NAME"
echo "  対象      : S3 + CloudFront + OAC"
echo "========================================"
echo ""

# 確認プロンプト（誤操作防止）
read -p "本当に全リソースを削除しますか？ (yes と入力して確認): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "キャンセルしました。"
  exit 0
fi

# ステップ1: S3バケットを空にする
# 理由: CloudFormationはバケットに中身があると削除できない
echo ""
echo ">>> [1/3] S3バケットのファイルを削除しています..."
aws s3 rm s3://$BUCKET_NAME --recursive
echo "    S3バケットが空になりました"

# ステップ2: CloudFormationスタックを削除
echo ""
echo ">>> [2/3] CloudFormationスタックを削除しています..."
aws cloudformation delete-stack --stack-name $STACK_NAME
echo "    削除リクエストを送信しました（完了まで数分かかります）"

# ステップ3: 削除完了を待機
echo ""
echo ">>> [3/3] 削除完了を待機しています..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME

echo ""
echo "========================================"
echo "  削除完了"
echo "  全AWSリソースが削除されました"
echo "========================================"
