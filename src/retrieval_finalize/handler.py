"""Presign a time-limited download URL once the object is restored."""
import os
import datetime as dt

import boto3

s3 = boto3.client("s3")
ddb = boto3.client("dynamodb")

BUCKET = os.environ["ARCHIVE_BUCKET"]
TABLE = os.environ["CATALOG_TABLE"]
TTL = int(os.environ.get("PRESIGN_TTL_SECS", "3600"))


def handler(event, _context):
    archive_id = event["archive_id"]
    object_key = event["object_key"]

    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": object_key},
        ExpiresIn=TTL,
    )

    ddb.update_item(
        TableName=TABLE,
        Key={"pk": {"S": f"ARCHIVE#{archive_id}"}, "sk": {"S": "META"}},
        UpdateExpression="SET #s = :s, last_retrieved_at = :t",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":s": {"S": "AVAILABLE"},
            ":t": {"S": dt.datetime.now(dt.timezone.utc).isoformat()},
        },
    )
    return {"archive_id": archive_id, "download_url": url, "expires_in": TTL}
