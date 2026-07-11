import json
import os

import boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]

    # userId (PK) で絞り込むQuery。Scanと違い、他ユーザーのデータを
    # 読み取る経路が存在しないため安全
    response = table.query(
        KeyConditionExpression=Key("userId").eq(user_id),
        ScanIndexForward=False,  # entryIdの降順 = 新しい日記が先頭
    )

    return {
        "statusCode": 200,
        "body": json.dumps(response.get("Items", [])),
    }
