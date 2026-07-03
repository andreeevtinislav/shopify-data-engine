terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.17"
    }
  }
}

# Credentials are sourced from SNOWFLAKE_ORGANIZATION_NAME / SNOWFLAKE_ACCOUNT_NAME /
# SNOWFLAKE_USER / SNOWFLAKE_PASSWORD (or SNOWFLAKE_PRIVATE_KEY) environment variables,
# or a ~/.snowflake/config profile. These must be admin-level credentials distinct from
# the SHOPIFY_LOADER_ROLE service account the pipeline runs as at runtime.
# ACCOUNTADMIN is required here (not just SYSADMIN) because this module also creates
# an account role and a service user, which need SECURITYADMIN-level privileges.
provider "snowflake" {
  role = "ACCOUNTADMIN"

  # snowflake_stage_internal and snowflake_table are preview resources in this
  # provider and must be opted into explicitly.
  preview_features_enabled = [
    "snowflake_stage_internal_resource",
    "snowflake_table_resource",
  ]
}
