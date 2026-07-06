output "secrets" {
  description = "Map of secret name -> aws_secretsmanager_secret resource"
  value       = aws_secretsmanager_secret.this
}

output "secret_arns" {
  description = "Map of secret name -> ARN"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "secret_names" {
  description = "Map of secret name -> provisioned secret name"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.name }
}
