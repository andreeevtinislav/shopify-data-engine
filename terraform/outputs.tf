output "warehouse_name" {
  value = snowflake_warehouse.shopify_wh.name
}

output "database_name" {
  value = snowflake_database.shopify_data.name
}

output "raw_schema_name" {
  value = snowflake_schema.raw.name
}

output "stage_fully_qualified_name" {
  value = snowflake_stage_internal.shopify_stage.fully_qualified_name
}

output "loader_role_name" {
  value = snowflake_account_role.shopify_loader.name
}

output "pipeline_service_user" {
  value = snowflake_service_user.shopify_pipeline_svc.name
}
