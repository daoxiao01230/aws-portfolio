import json
import os
import uuid
from datetime import datetime, timezone

import boto3

# TABLE_NAME はTerraformのenvironmentブロックから注入される
# (lambda.tf の aws_lambda_function.create_entry.environment を参照)
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    # HTTP API (JWT Authorizer) を通過したリクエストには
    # Cognitoが検証済みのJWTクレームが自動で付与される
    # sub = Cognitoユーザーの一意なID（ユーザーごとのデータ分離に使う）
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    body = json.loads(event.get("body") or "{}")
    content = body.get("content", "").strip()

    if not content:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "content is required"}),
        }

    now = datetime.now(timezone.utc).isoformat()
    entry = {
        "userId": user_id,
        # entryId: 作成時刻を先頭に置くことで、Query結果が自然に時系列順になる
        "entryId": f"{now}#{uuid.uuid4()}",
        "content": content,
        "createdAt": now,
        "updatedAt": now,
    }

    table.put_item(Item=entry)

    return {
        "statusCode": 201,
        "body": json.dumps(entry),
    }
