#!/bin/bash
# ============================================================
# GitHub Actions用 IAMユーザーセットアップスクリプト
# ============================================================
# 目的:
#   GitHub ActionsがS3デプロイとCloudFront Invalidationを
#   実行するための専用IAMユーザーを作成する。
#
# 最小権限の原則:
#   このユーザーは以下のみ許可する。
#   - S3: 対象バケットへの読み書き・削除・一覧
#   - CloudFront: 対象ディストリビューションのInvalidationのみ
#   それ以外のAWSリソースへのアクセスは一切不可。
#
# 前提条件:
#   - 実行するAWSユーザーにIAM操作権限があること
#   - AWS CLIの認証情報が設定済みであること（aws configure）
#   - terraform apply 完了後に実行すること（バケット名・DistributionIDが確定してから）
#
# 使い方:
#   bash scripts/setup-iam.sh
# ============================================================

set -e

# ============================================================
# 設定値（terraform applyの出力値に合わせて変更する）
# ============================================================
IAM_USER_NAME="github-actions-portfolio"
POLICY_NAME="portfolio-01-deploy"
BUCKET_NAME="portfolio-01-gratitude-journal-2026"
DISTRIBUTION_ID="E1GRY3X08NCCGZ"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "========================================"
echo "  IAMユーザーセットアップ"
echo "  ユーザー名     : $IAM_USER_NAME"
echo "  バケット名     : $BUCKET_NAME"
echo "  DistributionID : $DISTRIBUTION_ID"
echo "  AWSアカウントID: $AWS_ACCOUNT_ID"
echo "========================================"
echo ""

# ステップ1: IAMユーザーを作成
echo ">>> [1/3] IAMユーザーを作成しています..."
aws iam create-user --user-name $IAM_USER_NAME
echo "    作成完了: $IAM_USER_NAME"

# ステップ2: インラインポリシーを付与（最小権限）
echo ""
echo ">>> [2/3] インラインポリシーを付与しています..."
aws iam put-user-policy \
  --user-name $IAM_USER_NAME \
  --policy-name $POLICY_NAME \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"S3Deploy\",
        \"Effect\": \"Allow\",
        \"Action\": [
          \"s3:PutObject\",
          \"s3:DeleteObject\",
          \"s3:GetObject\",
          \"s3:ListBucket\"
        ],
        \"Resource\": [
          \"arn:aws:s3:::$BUCKET_NAME\",
          \"arn:aws:s3:::$BUCKET_NAME/*\"
        ]
      },
      {
        \"Sid\": \"CloudFrontInvalidation\",
        \"Effect\": \"Allow\",
        \"Action\": \"cloudfront:CreateInvalidation\",
        \"Resource\": \"arn:aws:cloudfront::$AWS_ACCOUNT_ID:distribution/$DISTRIBUTION_ID\"
      }
    ]
  }"
echo "    ポリシー付与完了: $POLICY_NAME"

# ステップ3: アクセスキーを発行
echo ""
echo ">>> [3/3] アクセスキーを発行しています..."
ACCESS_KEY=$(aws iam create-access-key --user-name $IAM_USER_NAME)
ACCESS_KEY_ID=$(echo $ACCESS_KEY | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
SECRET_ACCESS_KEY=$(echo $ACCESS_KEY | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")

echo ""
echo "========================================"
echo "  セットアップ完了"
echo "  以下の値をGitHub Secretsに登録してください"
echo "========================================"
echo ""
echo "  AWS_ACCESS_KEY_ID     = $ACCESS_KEY_ID"
echo "  AWS_SECRET_ACCESS_KEY = $SECRET_ACCESS_KEY"
echo "  AWS_REGION            = $(aws configure get region)"
echo "  S3_BUCKET_NAME        = $BUCKET_NAME"
echo "  CLOUDFRONT_DISTRIBUTION_ID = $DISTRIBUTION_ID"
echo ""
echo "  ⚠️  シークレットアクセスキーは今後表示されません。必ず今メモしてください。"
echo ""
echo "  GitHub Secrets登録先:"
echo "  Settings → Secrets and variables → Actions → New repository secret"
echo "========================================"
