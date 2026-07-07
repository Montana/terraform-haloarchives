data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Shared permissions: VPC ENI management, logs, X-Ray, KMS.
data "aws_iam_policy_document" "lambda_base" {
  statement {
    sid    = "VpcNetworking"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*:*"]
  }

  statement {
    sid    = "XRay"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Kms"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arn]
  }
}

# ---- ingest role ----
resource "aws_iam_role" "ingest" {
  name               = "${var.name_prefix}-ingest-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ingest" {
  source_policy_documents = [data.aws_iam_policy_document.lambda_base.json]

  statement {
    sid       = "PutArchiveObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:PutObjectTagging"]
    resources = ["${var.archive_bucket_arn}/*"]
  }

  statement {
    sid       = "CatalogWriteMeta"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [var.catalog_table_arn]
  }
}

resource "aws_iam_role_policy" "ingest" {
  name   = "ingest"
  role   = aws_iam_role.ingest.id
  policy = data.aws_iam_policy_document.ingest.json
}

# ---- catalog_writer role ----
resource "aws_iam_role" "catalog_writer" {
  name               = "${var.name_prefix}-catalog-writer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "catalog_writer" {
  source_policy_documents = [data.aws_iam_policy_document.lambda_base.json]

  statement {
    sid    = "ConsumeQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.ingest.arn]
  }

  statement {
    sid       = "CatalogWrite"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:BatchWriteItem"]
    resources = [var.catalog_table_arn, "${var.catalog_table_arn}/index/*"]
  }

  statement {
    sid       = "ReadObjectMetadata"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectTagging"]
    resources = ["${var.archive_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "catalog_writer" {
  name   = "catalog-writer"
  role   = aws_iam_role.catalog_writer.id
  policy = data.aws_iam_policy_document.catalog_writer.json
}
