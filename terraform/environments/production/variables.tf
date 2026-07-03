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

variable "dbt_transform_rsa_public_key" {
  description = <<-EOT
    RSA public key (single line, no header/trailer/newlines) for the dbt
    project's service user (DBT_TRANSFORM_SVC), used for key-pair
    authentication. Generate with:
      openssl genrsa -out dbt_transform_key.p8 4096
      openssl rsa -in dbt_transform_key.p8 -pubout -out dbt_transform_key.pub
    Then strip the PEM header/footer/newlines from dbt_transform_key.pub
    before passing it here (e.g. via TF_VAR_dbt_transform_rsa_public_key).
    The matching private key path goes into ../../../dbt/.env as
    SNOWFLAKE_PRIVATE_KEY_PATH.
  EOT
  type        = string
  sensitive   = true
}
