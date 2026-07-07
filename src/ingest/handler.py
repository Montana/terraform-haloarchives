"""POST /archives — accept an upload manifest, stage the object, seed catalog metadata."""
import json
import os
import uuid
import datetime as dt

import boto3

s3 = boto3.client("s3")
ddb = boto3.client("dynamodb")

BUCKET = os.environ["ARCHIVE_BUCKET"]
TABLE = os.environ["CATALOG_TABLE"]


def handler(event, _context):
    body = json.loads(event.get("body") or "{}")
    owner = body.get("owner", "unknown")
    content_type = body.get("content_type", "application/octet-stream")

    archive_id = str(uuid.uuid4())
    object_key = f"{owner}/{archive_id}"
    now = dt.datetime.now(dt.timezone.utc).isoformat()

    # Hand the caller a presigned PUT so large payloads never transit Lambda.
    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": object_key, "ContentType": content_type},
        ExpiresIn=900,
    )

    ddb.put_item(
        TableName=TABLE,
        Item={
            "pk": {"S": f"ARCHIVE#{archive_id}"},
            "sk": {"S": "META"},
            "owner": {"S": owner},
            "status": {"S": "PENDING_UPLOAD"},
            "created_at": {"S": now},
            "object_key": {"S": object_key},
        },
    )

    return {
        "statusCode": 201,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(
            {"archive_id": archive_id, "object_key": object_key, "upload_url": upload_url}
        ),
    }
