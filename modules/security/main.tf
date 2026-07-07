terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.replica]
    }
  }
}

# ---- Primary customer-managed key ----
data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "RootAccountAdmin"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowServiceUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = [
        "s3.amazonaws.com",
        "dynamodb.amazonaws.com",
        "sqs.amazonaws.com",
        "sns.amazonaws.com",
        "logs.${var.region}.amazonaws.com",
      ]
    }
  }
}

resource "aws_kms_key" "main" {
  description             = "${var.name_prefix} platform CMK"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# ---- Replica-region key (used only when cross-region replication is enabled) ----
resource "aws_kms_key" "replica" {
  provider                = aws.replica
  description             = "${var.name_prefix} replica CMK"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "replica" {
  provider      = aws.replica
  name          = "alias/${var.name_prefix}-replica"
  target_key_id = aws_kms_key.replica.key_id
}
