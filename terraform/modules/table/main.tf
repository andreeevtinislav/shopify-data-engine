# Note: database/schema are passed in as plain strings (not resource references),
# so this module has no automatic dependency on whatever created them. The caller
# is responsible for `depends_on = [module.database]` (see environments/production).
locals {
  tables = { for t in var.tables : "${t.database}.${t.schema}.${t.name}" => t }
}

resource "snowflake_table" "this" {
  for_each = local.tables

  database = each.value.database
  schema   = each.value.schema
  name     = each.value.name
  comment  = try(each.value.comment, null)

  dynamic "column" {
    for_each = each.value.columns
    content {
      name     = column.value.name
      type     = column.value.type
      nullable = column.value.nullable

      dynamic "default" {
        for_each = column.value.default_expression != null ? [column.value.default_expression] : []
        content {
          expression = default.value
        }
      }
    }
  }
}
