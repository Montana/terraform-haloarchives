"""SQS consumer — mark archives STORED once the object lands in S3.

Returns partial batch failures so only unprocessed records are retried.
"""
import json
import os
import datetime as dt
import urllib.parse

import boto3

ddb = boto3.client("dynamodb")
TABLE = os.environ["CATALOG_TABLE"]


def _archive_id_from_key(key: str) -> str:
    # object_key = "<owner>/<archive_id>"
    return key.rsplit("/", 1)[-1]


def handler(event, _context):
    failures = []
    for record in event.get("Records", []):
        try:
            payload = json.loads(record["body"])
            for s3rec in payload.get("Records", []):
                key = urllib.parse.unquote_plus(s3rec["s3"]["object"]["key"])
                size = s3rec["s3"]["object"].get("size", 0)
                archive_id = _archive_id_from_key(key)
                ddb.update_item(
                    TableName=TABLE,
                    Key={"pk": {"S": f"ARCHIVE#{archive_id}"}, "sk": {"S": "META"}},
                    UpdateExpression="SET #s = :s, size_bytes = :b, stored_at = :t",
                    ExpressionAttributeNames={"#s": "status"},
                    ExpressionAttributeValues={
                        ":s": {"S": "STORED"},
                        ":b": {"N": str(size)},
                        ":t": {"S": dt.datetime.now(dt.timezone.utc).isoformat()},
                    },
                )
        except Exception:  # noqa: BLE001 — surface to SQS for retry
            failures.append({"itemIdentifier": record["messageId"]})

    return {"batchItemFailures": failures}
