output "functions" {
  description = "Map of function name -> aws_lambda_function resource"
  value       = aws_lambda_function.this
}

output "function_arns" {
  description = "Map of function name -> ARN"
  value       = { for k, v in aws_lambda_function.this : k => v.arn }
}

output "invoke_arns" {
  description = "Map of function name -> invoke_arn (for API Gateway integrations)"
  value       = { for k, v in aws_lambda_function.this : k => v.invoke_arn }
}

output "function_names" {
  description = "Map of function name -> provisioned function name"
  value       = { for k, v in aws_lambda_function.this : k => v.function_name }
}
