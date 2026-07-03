locals {
  access_config = yamldecode(file("${path.module}/access.yml"))
}

module "access" {
  source = "../../modules/access"

  role_name            = local.access_config.role.name
  role_comment         = try(local.access_config.role.comment, null)
  service_user_name    = local.access_config.service_user.name
  service_user_comment = try(local.access_config.service_user.comment, null)

  warehouse_name              = module.warehouse.names[0]
  database_name               = module.database.databases["SHOPIFY_DATA"].name
  schema_name                 = module.database.schema_names["SHOPIFY_DATA.RAW"]
  schema_fully_qualified_name = module.database.schema_fully_qualified_names["SHOPIFY_DATA.RAW"]

  tables = module.table.tables
  stages = module.stage.stages

  pipeline_rsa_public_key = var.pipeline_rsa_public_key
}
