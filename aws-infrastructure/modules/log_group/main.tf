locals {
  log_groups = { for g in var.log_groups : g.name => g }
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log_groups

  name              = each.value.name
  retention_in_days = each.value.retention_in_days
}
