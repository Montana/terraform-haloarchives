terraform {
  required_providers {
    aws     = { source = "hashicorp/aws" }
    archive = { source = "hashicorp/archive" }
  }
}

locals {
  src_root = "${path.module}/../../src"
}

########################################
# Queues: ObjectCreated -> SQS -> catalog_writer
########################################
resource "aws_sqs_queue" "dlq" {
  name                              = "${var.name_prefix}-ingest-dlq"
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
  message_retention_seconds         = 1209600 # 14 days
  tags                              = var.tags
}

resource "aws_sqs_queue" "ingest" {
  name                              = "${var.name_prefix}-ingest"
  visibility_timeout_seconds        = 180
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
  tags = var.tags
}

# Allow S3 to publish ObjectCreated events into the queue.
data "aws_iam_policy_document" "queue_policy" {
  statement {
    sid       = "AllowS3Publish"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ingest.arn]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.archive_bucket_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "ingest" {
  queue_url = aws_sqs_queue.ingest.id
  policy    = data.aws_iam_policy_document.queue_policy.json
}

resource "aws_s3_bucket_notification" "archive" {
  bucket = var.archive_bucket_id
  queue {
    queue_arn = aws_sqs_queue.ingest.arn
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_sqs_queue_policy.ingest]
}

########################################
# Packaged Lambda source
########################################
data "archive_file" "ingest" {
  type        = "zip"
  source_dir  = "${local.src_root}/ingest"
  output_path = "${path.module}/.build/ingest.zip"
}

data "archive_file" "catalog_writer" {
  type        = "zip"
  source_dir  = "${local.src_root}/catalog_writer"
  output_path = "${path.module}/.build/catalog_writer.zip"
}

########################################
# ingest Lambda (invoked by API Gateway)
########################################
resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${var.name_prefix}-ingest"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.name_prefix}-ingest"
  role             = aws_iam_role.ingest.arn
  runtime          = var.lambda_runtime
  architectures    = [var.lambda_architecture]
  handler          = "handler.handler"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      ARCHIVE_BUCKET = var.archive_bucket_id
      CATALOG_TABLE  = var.catalog_table_name
      KMS_KEY_ARN    = var.kms_key_arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.ingest]
  tags       = var.tags
}

########################################
# catalog_writer Lambda (triggered by SQS)
########################################
resource "aws_cloudwatch_log_group" "catalog_writer" {
  name              = "/aws/lambda/${var.name_prefix}-catalog-writer"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "catalog_writer" {
  function_name    = "${var.name_prefix}-catalog-writer"
  role             = aws_iam_role.catalog_writer.arn
  runtime          = var.lambda_runtime
  architectures    = [var.lambda_architecture]
  handler          = "handler.handler"
  filename         = data.archive_file.catalog_writer.output_path
  source_code_hash = data.archive_file.catalog_writer.output_base64sha256
  timeout          = 120
  memory_size      = 256

  environment {
    variables = {
      CATALOG_TABLE = var.catalog_table_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.catalog_writer]
  tags       = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = aws_sqs_queue.ingest.arn
  function_name                      = aws_lambda_function.catalog_writer.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 20
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 20
  }
}
