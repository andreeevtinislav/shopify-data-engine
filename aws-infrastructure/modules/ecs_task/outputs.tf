output "task_definitions" {
  description = "Map of task family -> the wrapped Datadog ecs_fargate module instance"
  value       = module.datadog_ecs_fargate_task
}
