locals {
  warehouses = { for w in var.warehouses : w.name => w }
}

resource "snowflake_warehouse" "this" {
  for_each = local.warehouses

  name                = each.value.name
  warehouse_size      = each.value.size
  auto_suspend        = each.value.auto_suspend
  auto_resume         = each.value.auto_resume ? "true" : "false"
  initially_suspended = each.value.initially_suspended
  comment             = try(each.value.comment, null)
}
