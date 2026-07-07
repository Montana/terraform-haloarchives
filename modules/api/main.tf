resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "HaloArchives ingestion and retrieval API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigw/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId     = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      routeKey      = "$context.routeKey"
      status        = "$context.status"
      responseLen   = "$context.responseLength"
      integrationMs = "$context.integrationLatency"
    })
  }

  default_route_settings {
    throttling_burst_limit = 200
    throttling_rate_limit  = 100
  }

  tags = var.tags
}

########################################
# POST /archives  -> ingest Lambda (proxy)
########################################
resource "aws_apigatewayv2_integration" "ingest" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.ingest_lambda_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ingest" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /archives"
  target    = "integrations/${aws_apigatewayv2_integration.ingest.id}"
}

resource "aws_lambda_permission" "ingest" {
  statement_id  = "AllowApiGwInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.ingest_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

########################################
# POST /retrievals -> Step Functions StartExecution (service integration)
########################################
resource "aws_apigatewayv2_integration" "retrieval" {
  api_id              = aws_apigatewayv2_api.this.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "StepFunctions-StartExecution"
  credentials_arn     = var.retrieval_start_role_arn

  request_parameters = {
    StateMachineArn = var.retrieval_state_machine
    Input           = "$request.body"
  }

  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "retrieval" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /retrievals"
  target    = "integrations/${aws_apigatewayv2_integration.retrieval.id}"
}
