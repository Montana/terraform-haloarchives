########################################
# Cross-region replication (optional)
########################################
resource "aws_s3_bucket" "replica" {
  count               = var.enable_replication ? 1 : 0
  provider            = aws.replica
  bucket              = local.replica_bucket
  object_lock_enabled = var.enable_object_lock
  tags                = merge(var.tags, { Name = local.replica_bucket, Role = "archive-replica" })
}

resource "aws_s3_bucket_versioning" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.replica_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "replication_assume" {
  count = var.enable_replication ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count              = var.enable_replication ? 1 : 0
  name               = "${var.name_prefix}-s3-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "replication" {
  count = var.enable_replication ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.archive.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.archive.arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${aws_s3_bucket.replica[0].arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
    resources = [var.replica_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "replication" {
  count  = var.enable_replication ? 1 : 0
  name   = "replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

resource "aws_s3_bucket_replication_configuration" "archive" {
  count      = var.enable_replication ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.archive, aws_s3_bucket_versioning.replica]
  bucket     = aws_s3_bucket.archive.id
  role       = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "DEEP_ARCHIVE"
      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }
}
