# Wraps DataDog/ecs-datadog/aws's ecs_fargate module: injects the Datadog
# Agent container alongside the task's own app container, wires APM via UDS,
# and routes logs through FireLens to Datadog.
locals {
  tasks = { for t in var.tasks : t.family => t }
}

module "datadog_ecs_fargate_task" {
  source   = "DataDog/ecs-datadog/aws//modules/ecs_fargate"
  version  = "~> 1.0"
  for_each = local.tasks

  dd_api_key_secret = {
    arn = each.value.dd_api_key_secret_arn
  }
  dd_site    = each.value.dd_site
  dd_service = each.value.dd_service
  dd_env     = each.value.dd_env
  dd_version = each.value.dd_version

  dd_essential                     = true
  dd_is_datadog_dependency_enabled = true

  dd_apm = {
    enabled   = true
    profiling = false
  }

  dd_log_collection = {
    enabled = true
    fluentbit_config = {
      log_driver_configuration = {
        host_endpoint = "http-intake.logs.${each.value.dd_site}"
        service_name  = each.value.dd_service
        source_name   = "python"
      }
    }
  }

  family = each.value.family
  cpu    = each.value.cpu
  memory = each.value.memory

  # APM: wrap the CLI entrypoint with ddtrace-run so traces are emitted.
  # Ensure ddtrace is in the image (ingestion/pyproject.toml dependencies).
  container_definitions = jsonencode([
    {
      name      = each.value.container_name
      image     = each.value.image_uri
      essential = true
      command   = each.value.command
      environment = [
        for k, v in each.value.environment : { name = k, value = v }
      ]
    }
  ])

  requires_compatibilities = ["FARGATE"]
}
