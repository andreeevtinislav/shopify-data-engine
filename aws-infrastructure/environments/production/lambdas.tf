# role_arn/image_uri/environment reference other modules' outputs, so — like
# iam_roles.tf — the per-function extras are computed here rather than living
# in lambdas.yml, and merged onto the plain YAML shape.
locals {
  function_extras = {
    "shopify-webhook-receiver" = {
      role_arn  = module.iam_role.role_arns["shopify-webhook-receiver-exec"]
      image_uri = "${module.ecr.repository_urls["shopify-webhook-receiver"]}:${var.image_tag}"
      environment = {
        SHOPIFY_SHOP_DOMAIN              = var.shopify_shop_domain
        SHOPIFY_API_VERSION              = var.shopify_api_version
        SNOWFLAKE_ACCOUNT                = var.snowflake_account
        SNOWFLAKE_WAREHOUSE              = var.snowflake_warehouse
        SNOWFLAKE_DATABASE               = var.snowflake_database
        SNOWFLAKE_SCHEMA                 = var.snowflake_schema
        SNOWFLAKE_ROLE                   = var.snowflake_webhook_role
        SNOWFLAKE_USER                   = var.snowflake_webhook_user
        SHOPIFY_ACCESS_TOKEN_SECRET_ID   = module.secret.secret_names["shopify/access-token"]
        SHOPIFY_WEBHOOK_SECRET_SECRET_ID = module.secret.secret_names["shopify/webhook-secret"]
        SNOWFLAKE_PRIVATE_KEY_SECRET_ID  = module.secret.secret_names["snowflake/webhook-private-key"]
      }
    }
  }

  functions = [
    for f in yamldecode(file("${path.module}/lambdas.yml")).functions :
    merge(f, local.function_extras[f.name])
  ]
}

module "lambda" {
  source = "../../modules/lambda"

  functions = local.functions

  depends_on = [module.iam_role, module.ecr, module.secret, module.log_group]
}
