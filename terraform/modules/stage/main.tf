# Note: same caveat as the table module — database/schema are plain strings, so the
# caller must add `depends_on = [module.database]`.
locals {
  stages = { for s in var.stages : "${s.database}.${s.schema}.${s.name}" => s }
}

resource "snowflake_stage_internal" "this" {
  for_each = local.stages

  database = each.value.database
  schema   = each.value.schema
  name     = each.value.name
  comment  = try(each.value.comment, null)

  dynamic "file_format" {
    for_each = try(each.value.file_format_type, null) == "JSON" ? [1] : []
    content {
      json {
        compression = "AUTO"
      }
    }
  }
}
