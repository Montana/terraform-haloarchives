terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.replica]
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  archive_bucket = "${var.name_prefix}-archive-${random_id.suffix.hex}"
  logs_bucket    = "${var.name_prefix}-logs-${random_id.suffix.hex}"
  replica_bucket = "${var.name_prefix}-archive-replica-${random_id.suffix.hex}"
}

########################################
# Access-logging bucket
########################################
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket
  tags   = merge(var.tags, { Name = local.logs_bucket, Role = "access-logs" })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = 365
    }
  }
}

########################################
# Primary archive bucket (WORM)
########################################
resource "aws_s3_bucket" "archive" {
  bucket              = local.archive_bucket
  object_lock_enabled = var.enable_object_lock
  force_destroy       = false
  tags                = merge(var.tags, { Name = local.archive_bucket, Role = "archive" })
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "archive" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.archive.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.object_lock_retention_days
    }
  }
}

resource "aws_s3_bucket_logging" "archive" {
  bucket        = aws_s3_bucket.archive.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "archive-access/"
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    id     = "tiered-archival"
    status = "Enabled"
    filter {}

    dynamic "transition" {
      for_each = var.lifecycle_transitions
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# TLS-only bucket policy.
data "aws_iam_policy_document" "archive" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.archive.arn, "${aws_s3_bucket.archive.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "archive" {
  bucket = aws_s3_bucket.archive.id
  policy = data.aws_iam_policy_document.archive.json
}
