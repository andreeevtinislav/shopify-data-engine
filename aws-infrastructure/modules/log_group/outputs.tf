output "log_groups" {
  description = "Map of log group name -> aws_cloudwatch_log_group resource"
  value       = aws_cloudwatch_log_group.this
}

output "log_group_arns" {
  description = "Map of log group name -> ARN"
  value       = { for k, v in aws_cloudwatch_log_group.this : k => v.arn }
}
