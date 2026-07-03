variable "warehouse_name" {
  description = "Name of the Snowflake warehouse used to run ingestion loads/merges."
  type        = string
  default     = "SHOPIFY_WH"
}

variable "database_name" {
  description = "Name of the Snowflake database that holds Shopify data."
  type        = string
  default     = "SHOPIFY_DATA"
}

variable "raw_schema_name" {
  description = "Name of the schema holding raw, untransformed Shopify payloads."
  type        = string
  default     = "RAW"
}

variable "pipeline_rsa_public_key" {
  description = <<-EOT
    RSA public key (single line, no header/trailer/newlines) for the pipeline's
    service user, used for key-pair authentication. Generate with:
      openssl genrsa -out snowflake_key.p8 4096
      openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
    Then strip the PEM header/footer/newlines from snowflake_key.pub before
    passing it here (e.g. via TF_VAR_pipeline_rsa_public_key or a .tfvars file
    that is NOT committed). The matching private key path goes into the
    pipeline's own .env as SNOWFLAKE_PRIVATE_KEY_PATH.
  EOT
  type        = string
  sensitive   = true
}
