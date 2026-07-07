"""Initiate or poll a Glacier restore for one archived object."""
import os

import boto3

s3 = boto3.client("s3")
ddb = boto3.client("dynamodb")

BUCKET = os.environ["ARCHIVE_BUCKET"]
TABLE = os.environ["CATALOG_TABLE"]


def _set_status(archive_id, status):
    ddb.update_item(
        TableName=TABLE,
        Key={"pk": {"S": f"ARCHIVE#{archive_id}"}, "sk": {"S": "META"}},
        UpdateExpression="SET #s = :s",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": {"S": status}},
    )


def handler(event, _context):
    archive_id = event["archive_id"]
    object_key = event["object_key"]

    if event.get("action") == "check":
        head = s3.head_object(Bucket=BUCKET, Key=object_key)
        restore = head.get("Restore", "")
        restored = 'ongoing-request="false"' in restore
        if restored:
            _set_status(archive_id, "RESTORED")
        return {**event, "restored": restored}

    # Kick off the restore. Idempotent: a 409 means it is already in progress.
    try:
        s3.restore_object(
            Bucket=BUCKET,
            Key=object_key,
            RestoreRequest={"Days": 3, "GlacierJobParameters": {"Tier": "Standard"}},
        )
    except s3.exceptions.ClientError as err:
        if err.response["Error"]["Code"] != "RestoreAlreadyInProgress":
            raise
    _set_status(archive_id, "RESTORING")
    return {"archive_id": archive_id, "object_key": object_key, "restored": False}
