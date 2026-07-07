output "alarm_topic_arn" {
  description = "ARN of the alarm SNS topic."
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_url" {
  description = "Console URL for the CloudWatch dashboard."
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
