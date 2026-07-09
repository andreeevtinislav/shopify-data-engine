output "file_systems" {
  description = "Map of filesystem name -> aws_efs_file_system resource"
  value       = aws_efs_file_system.this
}

output "file_system_ids" {
  description = "Map of filesystem name -> ID"
  value       = { for k, v in aws_efs_file_system.this : k => v.id }
}

output "access_point_ids" {
  description = "Map of filesystem name -> access point ID (use this in the ECS volume config, not the raw filesystem)"
  value       = { for k, v in aws_efs_access_point.this : k => v.id }
}

output "access_point_arns" {
  description = "Map of filesystem name -> access point ARN (use this in the task role's elasticfilesystem:AccessPointArn condition)"
  value       = { for k, v in aws_efs_access_point.this : k => v.arn }
}

output "file_system_arns" {
  description = "Map of filesystem name -> filesystem ARN"
  value       = { for k, v in aws_efs_file_system.this : k => v.arn }
}
