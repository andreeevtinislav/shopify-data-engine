locals {
  clusters = { for c in var.clusters : c.name => c }
}

resource "aws_ecs_cluster" "this" {
  for_each = local.clusters

  name = each.value.name

  dynamic "setting" {
    for_each = each.value.container_insights ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }
}
