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

data "aws_iam_policy_document" "lambda_base" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*:*"]
  }
  statement {
    sid       = "XRay"
    effect    = "Allow"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
  statement {
    sid       = "Kms"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

# ---- initiate role ----
resource "aws_iam_role" "initiate" {
  name               = "${var.name_prefix}-retrieval-initiate-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "initiate" {
  source_policy_documents = [data.aws_iam_policy_document.lambda_base.json]
  statement {
    sid       = "RestoreObject"
    effect    = "Allow"
    actions   = ["s3:RestoreObject", "s3:GetObject", "s3:HeadObject", "s3:GetObjectAttributes"]
    resources = ["${var.archive_bucket_arn}/*"]
  }
  statement {
    sid       = "CatalogUpdate"
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
    resources = [var.catalog_table_arn]
  }
}

resource "aws_iam_role_policy" "initiate" {
  name   = "initiate"
  role   = aws_iam_role.initiate.id
  policy = data.aws_iam_policy_document.initiate.json
}

# ---- finalize role ----
resource "aws_iam_role" "finalize" {
  name               = "${var.name_prefix}-retrieval-finalize-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "finalize" {
  source_policy_documents = [data.aws_iam_policy_document.lambda_base.json]
  statement {
    sid       = "PresignRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.archive_bucket_arn}/*"]
  }
  statement {
    sid       = "CatalogUpdate"
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [var.catalog_table_arn]
  }
}

resource "aws_iam_role_policy" "finalize" {
  name   = "finalize"
  role   = aws_iam_role.finalize.id
  policy = data.aws_iam_policy_document.finalize.json
}

# ---- Step Functions execution role ----
data "aws_iam_policy_document" "sfn_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.name_prefix}-retrieval-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "sfn" {
  statement {
    sid       = "InvokeLambdas"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.initiate.arn, aws_lambda_function.finalize.arn]
  }
  statement {
    sid    = "Observability"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies", "logs:DescribeLogGroups",
      "xray:PutTraceSegments", "xray:PutTelemetryRecords",
      "xray:GetSamplingRules", "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn" {
  name   = "sfn"
  role   = aws_iam_role.sfn.id
  policy = data.aws_iam_policy_document.sfn.json
}

# ---- Role API Gateway assumes to start executions ----
data "aws_iam_policy_document" "api_start_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_start" {
  name               = "${var.name_prefix}-api-start-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.api_start_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "api_start" {
  name = "start-execution"
  role = aws_iam_role.api_start.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.retrieval.arn
    }]
  })
}
