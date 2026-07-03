# Least-privilege role the pipeline authenticates as at runtime — distinct from the
# ACCOUNTADMIN-level credentials Terraform itself uses to provision this infra.
resource "snowflake_account_role" "shopify_loader" {
  name    = "SHOPIFY_LOADER_ROLE"
  comment = "Runtime role for the Shopify ingestion pipeline. Read/write on RAW schema only."
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  account_role_name = snowflake_account_role.shopify_loader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.shopify_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  account_role_name = snowflake_account_role.shopify_loader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.shopify_data.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "raw_schema_all" {
  account_role_name = snowflake_account_role.shopify_loader.name
  all_privileges    = true
  on_schema {
    schema_name = snowflake_schema.raw.fully_qualified_name
  }
}

# Covers the tables/stage/file format created above.
resource "snowflake_grant_privileges_to_account_role" "raw_schema_tables_all" {
  account_role_name = snowflake_account_role.shopify_loader.name
  all_privileges    = true
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = snowflake_schema.raw.fully_qualified_name
    }
  }
}

# Grants on any table added to RAW later (e.g. a future products/customers extractor)
# without needing to touch this access module again.
resource "snowflake_grant_privileges_to_account_role" "raw_schema_future_tables_all" {
  account_role_name = snowflake_account_role.shopify_loader.name
  all_privileges    = true
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = snowflake_schema.raw.fully_qualified_name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "raw_schema_stages_all" {
  account_role_name = snowflake_account_role.shopify_loader.name
  all_privileges    = true
  on_schema_object {
    all {
      object_type_plural = "STAGES"
      in_schema          = snowflake_schema.raw.fully_qualified_name
    }
  }
}

# Service user the pipeline authenticates as (key-pair auth recommended: set
# rsa_public_key after generating a key pair locally, then use the matching
# private key as SNOWFLAKE_PRIVATE_KEY_PATH in the pipeline's .env).
resource "snowflake_service_user" "shopify_pipeline_svc" {
  name              = "SHOPIFY_PIPELINE_SVC"
  comment           = "Service account used by the Shopify ingestion pipeline (scripts/sync_orders.py)."
  default_warehouse = snowflake_warehouse.shopify_wh.name
  default_role      = snowflake_account_role.shopify_loader.name
  default_namespace = "${snowflake_database.shopify_data.name}.${snowflake_schema.raw.name}"
  rsa_public_key    = var.pipeline_rsa_public_key
}

resource "snowflake_grant_account_role" "loader_to_svc_user" {
  role_name = snowflake_account_role.shopify_loader.name
  user_name = snowflake_service_user.shopify_pipeline_svc.name
}
