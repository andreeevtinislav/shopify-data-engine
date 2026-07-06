# Note: warehouse is a plain name string (not a resource reference), consistent
# with modules/access's `warehouse_name` convention. schedule_minutes is the only
# schedule shape exposed so far (interval-based); add cron/after support here if
# a future task needs it.
locals {
  tasks = { for t in var.tasks : "${t.database}.${t.schema}.${t.name}" => t }
}

resource "snowflake_task" "this" {
  for_each = local.tasks

  database      = each.value.database
  schema        = each.value.schema
  name          = each.value.name
  warehouse     = try(each.value.warehouse, null)
  comment       = try(each.value.comment, null)
  when          = try(each.value.when, null)
  sql_statement = each.value.sql_statement
  started       = each.value.started

  dynamic "schedule" {
    for_each = each.value.schedule_minutes != null ? [each.value.schedule_minutes] : []
    content {
      minutes = schedule.value
    }
  }
}
