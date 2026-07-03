output "warehouse_names" {
  value = module.warehouse.names
}

output "database_names" {
  value = keys(module.database.databases)
}

output "raw_schema_name" {
  value = module.database.schema_names["SHOPIFY_DATA.RAW"]
}

output "stage_fully_qualified_names" {
  value = module.stage.fully_qualified_names
}

output "loader_role_name" {
  value = module.access.role_name
}

output "pipeline_service_user" {
  value = module.access.service_user_name
}
