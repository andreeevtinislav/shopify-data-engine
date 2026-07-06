output "roles" {
  description = "Map of role name -> aws_iam_role resource"
  value       = aws_iam_role.this
}

output "role_arns" {
  description = "Map of role name -> ARN"
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "role_names" {
  description = "Map of role name -> provisioned role name"
  value       = { for k, v in aws_iam_role.this : k => v.name }
}
