output "state_machine_arn" {
  description = "ARN of the retrieval state machine."
  value       = aws_sfn_state_machine.retrieval.arn
}

output "initiate_lambda_name" {
  description = "Name of the initiate Lambda."
  value       = aws_lambda_function.initiate.function_name
}

output "finalize_lambda_name" {
  description = "Name of the finalize Lambda."
  value       = aws_lambda_function.finalize.function_name
}

output "api_start_role_arn" {
  description = "Role ARN API Gateway assumes to start executions."
  value       = aws_iam_role.api_start.arn
}
