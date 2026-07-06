locals {
  access_config = yamldecode(file("${path.module}/access.yml"))
}

module "access" {
  source = "../../modules/access"

  roles          = local.access_config.roles
  warehouse_name = module.warehouse.names[0]

  schema_names                 = module.database.schema_names
  schema_fully_qualified_names = module.database.schema_fully_qualified_names

  tables = module.table.tables
  stages = module.stage.stages

  service_user_rsa_public_keys = {
    SHOPIFY_LOADER_ROLE  = var.pipeline_rsa_public_key
    SHOPIFY_WEBHOOK_ROLE = var.webhook_rsa_public_key
    DBT_TRANSFORM_ROLE   = var.dbt_transform_rsa_public_key
  }
}
