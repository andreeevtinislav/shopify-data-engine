locals {
  databases = { for d in var.databases : d.name => d }

  # Flatten to "<database>.<schema>" so all schemas across all databases can be
  # created with a single for_each.
  schemas = merge([
    for d in var.databases : {
      for s in d.schemas : "${d.name}.${s.name}" => merge(s, { database = d.name })
    }
  ]...)
}

resource "snowflake_database" "this" {
  for_each = local.databases

  name    = each.value.name
  comment = try(each.value.comment, null)
}

resource "snowflake_schema" "this" {
  for_each = local.schemas

  database = snowflake_database.this[each.value.database].name
  name     = each.value.name
  comment  = try(each.value.comment, null)
}
