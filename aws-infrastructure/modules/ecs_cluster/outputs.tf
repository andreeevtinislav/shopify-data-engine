output "clusters" {
  description = "Map of cluster name -> aws_ecs_cluster resource"
  value       = aws_ecs_cluster.this
}

output "cluster_arns" {
  description = "Map of cluster name -> ARN"
  value       = { for k, v in aws_ecs_cluster.this : k => v.arn }
}

output "cluster_names" {
  description = "Map of cluster name -> provisioned cluster name"
  value       = { for k, v in aws_ecs_cluster.this : k => v.name }
}
