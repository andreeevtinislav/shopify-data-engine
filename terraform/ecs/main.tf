# Datadog API key stored in AWS Secrets Manager.
# The key is never hard-coded; pass it at apply time via TF_VAR_dd_api_key.
resource "aws_secretsmanager_secret" "datadog_api_key" {
  name        = "datadog/api-key"
  description = "Datadog API key for shopify-engine ECS Fargate observability"
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = var.dd_api_key
}

# Datadog ECS Fargate sidecar module.
# Injects the Datadog Agent container alongside the shopify-engine app container,
# wires APM via UDS, and routes logs through FireLens to Datadog.
module "datadog_ecs_fargate_task" {
  source  = "DataDog/ecs-datadog/aws//modules/ecs_fargate"
  version = "~> 1.0"

  dd_api_key_secret = {
    arn = aws_secretsmanager_secret.datadog_api_key.arn
  }
  dd_site    = var.dd_site
  dd_service = var.dd_service
  dd_env     = var.dd_env
  dd_version = var.dd_version

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
        host_endpoint = "http-intake.logs.${var.dd_site}"
        service_name  = var.dd_service
        source_name   = "python"
      }
    }
  }

  family = var.task_family
  cpu    = 512
  memory = 1024

  # APM: wrap the CLI entrypoint with ddtrace-run so traces are emitted.
  # Ensure ddtrace is in the image: add `ddtrace` to ingestion/pyproject.toml dependencies.
  container_definitions = jsonencode([
    {
      name      = "shopify-engine"
      image     = var.ecr_image_uri
      essential = true
      command   = ["ddtrace-run", "sync-orders"]
      environment = [
        { name = "DD_SERVICE", value = var.dd_service },
        { name = "DD_ENV",     value = var.dd_env },
        { name = "DD_VERSION", value = var.dd_version },
      ]
    }
  ])

  requires_compatibilities = ["FARGATE"]
}
