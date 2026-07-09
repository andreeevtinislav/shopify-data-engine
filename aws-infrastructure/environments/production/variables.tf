variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "image_tag" {
  description = <<-EOT
    Tag to deploy for both the webhook receiver and batch sync images. ECR
    repos are created by this same config (module.ecr), which creates a
    bootstrapping order: a repo must exist and already contain this tag
    before the Lambda / ECS task resources referencing it can be created.
    First apply:
      terraform apply -target=module.ecr
    then build/push (see ../../../ingestion/Dockerfile.webhook and
    ../../../ingestion/Dockerfile if one exists for the batch image) to the
    resulting repository_url, then run a full `terraform apply`.
  EOT
  type        = string
  default     = "latest"
}

# --- Secrets, fetched by their respective consumers (webhook Lambda / ECS
# task) from Secrets Manager. Pass these in at apply time (e.g.
# TF_VAR_shopify_access_token) — never commit them. ---

variable "shopify_access_token" {
  description = "Shopify Admin API access token."
  type        = string
  sensitive   = true
}

variable "shopify_webhook_secret" {
  description = "Shopify webhook signing secret, used to verify X-Shopify-Hmac-Sha256. Set this as the callbackUrl's shared secret when registering webhooks."
  type        = string
  sensitive   = true
}

variable "snowflake_webhook_private_key_pem" {
  description = <<-EOT
    PEM-encoded RSA private key for SHOPIFY_WEBHOOK_SVC. The matching public
    key is granted access via ../../../terraform/environments/production's
    webhook_rsa_public_key variable — generate both from the same key pair:
      openssl genrsa -out webhook_key.p8 4096
      openssl rsa -in webhook_key.p8 -pubout -out webhook_key.pub
    Pass the *private* key's contents here; the public key (stripped of
    header/footer/newlines) goes into terraform/environments/production instead.
  EOT
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key (for the batch sync ECS Fargate task's Agent sidecar)."
  type        = string
  sensitive   = true
}

variable "snowflake_pipeline_private_key_pem" {
  description = "PEM-encoded RSA private key for SHOPIFY_PIPELINE_SVC (contents of ../../../ingestion/secrets/snowflake_key.p8), used by the Airflow container's incremental-sync task."
  type        = string
  sensitive   = true
}

variable "snowflake_dbt_private_key_pem" {
  description = "PEM-encoded RSA private key for DBT_TRANSFORM_SVC (contents of ../../../dbt/secrets/dbt_transform_key.p8), used by the Airflow container's dbt run/snapshot tasks."
  type        = string
  sensitive   = true
}

# --- Non-sensitive settings, passed to the webhook Lambda as plain
# environment variables (see Settings.from_env() in
# ingestion/src/shopify_engine/config.py). ---

variable "shopify_shop_domain" {
  description = "Shopify shop domain, e.g. my-store.myshopify.com"
  type        = string
}

variable "shopify_api_version" {
  description = "Shopify Admin API version, e.g. 2025-10"
  type        = string
}

variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
}

variable "snowflake_warehouse" {
  type    = string
  default = "SHOPIFY_WH"
}

variable "snowflake_database" {
  type    = string
  default = "SHOPIFY_DATA"
}

variable "snowflake_schema" {
  type    = string
  default = "RAW"
}

variable "snowflake_webhook_role" {
  description = "Must match the role name provisioned in ../../../terraform/environments/production/access.yml"
  type        = string
  default     = "SHOPIFY_WEBHOOK_ROLE"
}

variable "snowflake_webhook_user" {
  description = "Must match the service_user name provisioned in ../../../terraform/environments/production/access.yml"
  type        = string
  default     = "SHOPIFY_WEBHOOK_SVC"
}

variable "snowflake_pipeline_role" {
  description = "Must match the role name provisioned in ../../../terraform/environments/production/access.yml"
  type        = string
  default     = "SHOPIFY_LOADER_ROLE"
}

variable "snowflake_pipeline_user" {
  description = "Must match the service_user name provisioned in ../../../terraform/environments/production/access.yml"
  type        = string
  default     = "SHOPIFY_PIPELINE_SVC"
}

variable "snowflake_dbt_role" {
  description = "Must match the role name provisioned in ../../../terraform/environments/production/access.yml"
  type        = string
  default     = "DBT_TRANSFORM_ROLE"
}

variable "snowflake_dbt_user" {
  description = "Must match the service_user name provisioned in ../../../terraform/environments/production/access.yml"
  type        = string
  default     = "DBT_TRANSFORM_SVC"
}

variable "airflow_ui_allowed_cidr" {
  description = <<-EOT
    CIDR block allowed to reach the Airflow webserver on port 8080. Set this
    to your own IP (e.g. "203.0.113.4/32" — check https://checkip.amazonaws.com)
    rather than leaving it wide open; Airflow's own login screen is a second
    layer, not a substitute for network-level restriction.
  EOT
  type        = string
}
