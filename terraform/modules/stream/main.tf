# Note: on_table is a plain fully-qualified table identifier string (not a
# resource reference), consistent with modules/table's database/schema
# convention — the caller is responsible for `depends_on = [module.table]`
# (see environments/production).
locals {
  streams = { for s in var.streams : "${s.database}.${s.schema}.${s.name}" => s }
}

resource "snowflake_stream_on_table" "this" {
  for_each = local.streams

  database = each.value.database
  schema   = each.value.schema
  name     = each.value.name
  table    = each.value.on_table
  comment  = try(each.value.comment, null)
}
