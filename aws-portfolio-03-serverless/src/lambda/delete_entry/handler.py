import json
import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    entry_id = event["pathParameters"]["id"]

    # userIdをKeyに含めることで、他ユーザーのentryIdを削除できないようにする
    table.delete_item(Key={"userId": user_id, "entryId": entry_id})

    return {
        "statusCode": 204,
        "body": "",
    }
