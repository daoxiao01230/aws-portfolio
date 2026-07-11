import json
import os
from datetime import datetime, timezone

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    entry_id = event["pathParameters"]["id"]
    body = json.loads(event.get("body") or "{}")
    content = body.get("content", "").strip()

    if not content:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "content is required"}),
        }

    # Key条件にuserIdを含めることで、他ユーザーのentryIdを推測されても
    # 更新できないようにする（IDOR対策）
    table.update_item(
        Key={"userId": user_id, "entryId": entry_id},
        UpdateExpression="SET content = :content, updatedAt = :updatedAt",
        ConditionExpression="attribute_exists(userId)",
        ExpressionAttributeValues={
            ":content": content,
            ":updatedAt": datetime.now(timezone.utc).isoformat(),
        },
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"entryId": entry_id, "content": content}),
    }
