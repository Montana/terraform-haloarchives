output "api_id" {
  description = "HTTP API id."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Invoke URL for the default stage."
  value       = aws_apigatewayv2_stage.default.invoke_url
}
