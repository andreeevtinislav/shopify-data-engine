module "secret" {
  source = "../../modules/secret"

  secrets = yamldecode(file("${path.module}/secrets.yml")).secrets

  secret_values = {
    "shopify/access-token"          = var.shopify_access_token
    "shopify/webhook-secret"        = var.shopify_webhook_secret
    "snowflake/webhook-private-key" = var.snowflake_webhook_private_key_pem
    "datadog/api-key"               = var.datadog_api_key
  }
}
