terraform {
  required_providers {
    aws     = { source = "hashicorp/aws" }
    archive = { source = "hashicorp/archive" }
  }
}

locals {
  src_root = "${path.module}/../../src"
}

data "archive_file" "initiate" {
  type        = "zip"
  source_dir  = "${local.src_root}/retrieval_initiate"
  output_path = "${path.module}/.build/initiate.zip"
}

data "archive_file" "finalize" {
  type        = "zip"
  source_dir  = "${local.src_root}/retrieval_finalize"
  output_path = "${path.module}/.build/finalize.zip"
}

########################################
# Lambdas
########################################
resource "aws_cloudwatch_log_group" "initiate" {
  name              = "/aws/lambda/${var.name_prefix}-retrieval-initiate"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "initiate" {
  function_name    = "${var.name_prefix}-retrieval-initiate"
  role             = aws_iam_role.initiate.arn
  runtime          = var.lambda_runtime
  architectures    = [var.lambda_architecture]
  handler          = "handler.handler"
  filename         = data.archive_file.initiate.output_path
  source_code_hash = data.archive_file.initiate.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      ARCHIVE_BUCKET = var.archive_bucket_id
      CATALOG_TABLE  = var.catalog_table_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.initiate]
  tags       = var.tags
}

resource "aws_cloudwatch_log_group" "finalize" {
  name              = "/aws/lambda/${var.name_prefix}-retrieval-finalize"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "finalize" {
  function_name    = "${var.name_prefix}-retrieval-finalize"
  role             = aws_iam_role.finalize.arn
  runtime          = var.lambda_runtime
  architectures    = [var.lambda_architecture]
  handler          = "handler.handler"
  filename         = data.archive_file.finalize.output_path
  source_code_hash = data.archive_file.finalize.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      ARCHIVE_BUCKET   = var.archive_bucket_id
      CATALOG_TABLE    = var.catalog_table_name
      PRESIGN_TTL_SECS = "3600"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.finalize]
  tags       = var.tags
}

########################################
# Step Functions state machine
########################################
resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/vendedlogs/states/${var.name_prefix}-retrieval"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_sfn_state_machine" "retrieval" {
  name     = "${var.name_prefix}-retrieval"
  role_arn = aws_iam_role.sfn.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Async Glacier retrieval: initiate restore, poll, presign, notify."
    StartAt = "InitiateRestore"
    States = {
      InitiateRestore = {
        Type     = "Task"
        Resource = aws_lambda_function.initiate.arn
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 5
          MaxAttempts     = 3
          BackoffRate     = 2.0
        }]
        Next = "WaitForRestore"
      }
      WaitForRestore = {
        Type    = "Wait"
        Seconds = 900
        Next    = "CheckRestore"
      }
      CheckRestore = {
        Type     = "Task"
        Resource = aws_lambda_function.initiate.arn
        Parameters = {
          "action"       = "check"
          "archive_id.$" = "$.archive_id"
          "object_key.$" = "$.object_key"
        }
        Next = "RestoreComplete?"
      }
      "RestoreComplete?" = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.restored"
          BooleanEquals = true
          Next          = "Finalize"
        }]
        Default = "WaitForRestore"
      }
      Finalize = {
        Type     = "Task"
        Resource = aws_lambda_function.finalize.arn
        End      = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = var.tags
}
