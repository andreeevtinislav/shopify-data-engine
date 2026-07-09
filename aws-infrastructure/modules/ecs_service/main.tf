# A "service" here is a long-running Fargate task kept alive continuously
# (e.g. Airflow's scheduler+webserver) — distinct from modules/ecs_task, which
# only registers a task *definition* meant to be invoked periodically
# (RunTask), not run as a persistent service.
data "aws_region" "current" {}

locals {
  services = { for s in var.services : s.name => s }
}

resource "aws_ecs_task_definition" "this" {
  for_each = local.services

  family                   = each.value.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = each.value.execution_role_arn
  task_role_arn            = each.value.task_role_arn

  dynamic "volume" {
    for_each = each.value.efs_mounts
    content {
      name = "efs-${replace(volume.value.container_path, "/", "-")}"
      efs_volume_configuration {
        file_system_id     = volume.value.file_system_id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = volume.value.access_point_id
          iam             = "ENABLED"
        }
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = each.value.container_name
      image     = each.value.image_uri
      essential = true
      command   = each.value.command
      portMappings = each.value.container_port != null ? [
        { containerPort = each.value.container_port, protocol = "tcp" }
      ] : []
      environment = [for k, v in each.value.environment : { name = k, value = v }]
      secrets     = [for k, arn in each.value.secrets : { name = k, valueFrom = arn }]
      mountPoints = [
        for m in each.value.efs_mounts : {
          sourceVolume  = "efs-${replace(m.container_path, "/", "-")}"
          containerPath = m.container_path
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = each.value.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = each.value.name
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  for_each = local.services

  name            = each.value.name
  cluster         = each.value.cluster_arn
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = each.value.subnet_ids
    security_groups  = each.value.security_group_ids
    assign_public_ip = each.value.assign_public_ip
  }
}
