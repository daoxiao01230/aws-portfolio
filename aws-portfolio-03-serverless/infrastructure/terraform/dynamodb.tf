# ============================================================
# DynamoDB テーブル
# シングルテーブル設計: PK=userId（Cognitoのsub）, SK=entryId
# ユーザーごとのQueryで一覧取得できるため、Scanが不要になる
# ============================================================
resource "aws_dynamodb_table" "entries" {
  name         = "${var.project_name}-entries"
  billing_mode = "PAY_PER_REQUEST"
  # 理由: アクセス量が読めないポートフォリオ用途では、
  #       キャパシティ事前予約(PROVISIONED)より従量課金が安全

  hash_key  = "userId"
  range_key = "entryId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "entryId"
    type = "S"
  }

  # -------------------------------------------------------
  # 【設定しない項目】
  # -------------------------------------------------------
  # point_in_time_recovery: 無効（デフォルト）
  #   理由: 学習用データのため、35日間ポイントインタイム復旧は過剰。
  #         本番相当データを扱うPhaseで検討。
  #
  # server_side_encryption: 明示しない
  #   理由: DynamoDBはデフォルトで保存時暗号化(AWS所有キー)が有効。

  tags = {
    Project = var.project_name
  }
}
