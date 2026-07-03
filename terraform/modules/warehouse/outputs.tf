output "warehouses" {
  description = "Map of warehouse name -> snowflake_warehouse resource"
  value       = snowflake_warehouse.this
}

output "names" {
  description = "List of provisioned warehouse names"
  value       = [for w in snowflake_warehouse.this : w.name]
}
