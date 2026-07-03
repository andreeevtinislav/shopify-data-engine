# One-time remap from the flat (pre-modularization) resource addresses to their new
# module addresses, so `terraform plan` shows no changes for already-provisioned
# infra instead of destroy+recreate. Safe to delete once everyone's state has picked
# these up (Terraform records the move in state on the next apply).

moved {
  from = snowflake_warehouse.shopify_wh
  to   = module.warehouse.snowflake_warehouse.this["SHOPIFY_WH"]
}

moved {
  from = snowflake_database.shopify_data
  to   = module.database.snowflake_database.this["SHOPIFY_DATA"]
}

moved {
  from = snowflake_schema.raw
  to   = module.database.snowflake_schema.this["SHOPIFY_DATA.RAW"]
}

moved {
  from = snowflake_table.shopify_orders_json
  to   = module.table.snowflake_table.this["SHOPIFY_DATA.RAW.SHOPIFY_ORDERS_JSON"]
}

moved {
  from = snowflake_table.sync_state
  to   = module.table.snowflake_table.this["SHOPIFY_DATA.RAW._SYNC_STATE"]
}

moved {
  from = snowflake_stage_internal.shopify_stage
  to   = module.stage.snowflake_stage_internal.this["SHOPIFY_DATA.RAW.SHOPIFY_STAGE"]
}

moved {
  from = snowflake_account_role.shopify_loader
  to   = module.access.snowflake_account_role.this
}

moved {
  from = snowflake_grant_privileges_to_account_role.warehouse_usage
  to   = module.access.snowflake_grant_privileges_to_account_role.warehouse_usage
}

moved {
  from = snowflake_grant_privileges_to_account_role.database_usage
  to   = module.access.snowflake_grant_privileges_to_account_role.database_usage
}

moved {
  from = snowflake_grant_privileges_to_account_role.raw_schema_all
  to   = module.access.snowflake_grant_privileges_to_account_role.schema_all
}

moved {
  from = snowflake_grant_privileges_to_account_role.raw_schema_tables_all
  to   = module.access.snowflake_grant_privileges_to_account_role.schema_tables_all
}

moved {
  from = snowflake_grant_privileges_to_account_role.raw_schema_future_tables_all
  to   = module.access.snowflake_grant_privileges_to_account_role.schema_future_tables_all
}

moved {
  from = snowflake_grant_privileges_to_account_role.raw_schema_stages_all
  to   = module.access.snowflake_grant_privileges_to_account_role.schema_stages_all
}

moved {
  from = snowflake_service_user.shopify_pipeline_svc
  to   = module.access.snowflake_service_user.this
}

moved {
  from = snowflake_grant_account_role.loader_to_svc_user
  to   = module.access.snowflake_grant_account_role.loader_to_svc_user
}
