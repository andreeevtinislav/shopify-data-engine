output "services" {
  description = "Map of service name -> aws_ecs_service resource"
  value       = aws_ecs_service.this
}

output "task_definition_arns" {
  description = "Map of service name -> task definition ARN"
  value       = { for k, v in aws_ecs_task_definition.this : k => v.arn }
}
