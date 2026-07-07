########################################
# Alarm notification topic
########################################
resource "aws_sns_topic" "alarms" {
  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

########################################
# Ingestion DLQ depth
########################################
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.name_prefix}-ingest-dlq-not-empty"
  alarm_description   = "Messages have landed in the ingestion DLQ."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.ingestion_dlq_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { QueueName = var.ingestion_dlq_name }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

########################################
# Per-Lambda error alarms
########################################
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = toset(var.lambda_function_names)
  alarm_name          = "${each.value}-errors"
  alarm_description   = "Elevated error rate for ${each.value}."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = each.value }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

########################################
# DynamoDB throttling
########################################
resource "aws_cloudwatch_metric_alarm" "ddb_throttle" {
  alarm_name          = "${var.name_prefix}-catalog-throttled"
  alarm_description   = "Catalog table is throttling requests."
  namespace           = "AWS/DynamoDB"
  metric_name         = "ThrottledRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { TableName = var.catalog_table_name }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

########################################
# Dashboard
########################################
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          title  = "Lambda invocations & errors"
          region = var.region
          view   = "timeSeries"
          metrics = concat(
            [for fn in var.lambda_function_names : ["AWS/Lambda", "Invocations", "FunctionName", fn]],
            [for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn]],
          )
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          title   = "Ingest queue depth"
          region  = var.region
          view    = "timeSeries"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.ingestion_queue_name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.ingestion_dlq_name],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          title   = "API 4xx / 5xx"
          region  = var.region
          view    = "timeSeries"
          metrics = [
            ["AWS/ApiGateway", "4xx", "ApiId", var.api_id],
            ["AWS/ApiGateway", "5xx", "ApiId", var.api_id],
            ["AWS/ApiGateway", "Count", "ApiId", var.api_id],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6,
        properties = {
          title   = "Catalog capacity"
          region  = var.region
          view    = "timeSeries"
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.catalog_table_name],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", var.catalog_table_name],
          ]
        }
      },
    ]
  })
}
