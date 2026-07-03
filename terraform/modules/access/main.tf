# Least-privilege role the pipeline authenticates as at runtime — distinct from the
# ACCOUNTADMIN-level credentials Terraform itself uses to provision infra.
resource "snowflake_account_role" "this" {
  name    = var.role_name
  comment = var.role_comment
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  account_role_name = snowflake_account_role.this.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.warehouse_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  account_role_name = snowflake_account_role.this.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = var.database_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_all" {
  account_role_name = snowflake_account_role.this.name
  all_privileges    = true
  on_schema {
    schema_name = var.schema_fully_qualified_name
  }
}

# "ON ALL TABLES"/"ON ALL STAGES" only grant against objects that exist at apply
# time. var.tables/var.stages are plain data (not read), so referencing them alone
# wouldn't order this after their creation — the explicit depends_on is required.
# Learned this the hard way: without it, this grant and the table/stage creation
# run concurrently and can complete before the objects exist, silently granting
# nothing.
resource "snowflake_grant_privileges_to_account_role" "schema_tables_all" {
  account_role_name = snowflake_account_role.this.name
  all_privileges    = true
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = var.schema_fully_qualified_name
    }
  }

  depends_on = [var.tables]
}

# Covers tables added later (e.g. a future products/customers extractor) without
# needing to touch this module again.
resource "snowflake_grant_privileges_to_account_role" "schema_future_tables_all" {
  account_role_name = snowflake_account_role.this.name
  all_privileges    = true
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = var.schema_fully_qualified_name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_stages_all" {
  account_role_name = snowflake_account_role.this.name
  all_privileges    = true
  on_schema_object {
    all {
      object_type_plural = "STAGES"
      in_schema          = var.schema_fully_qualified_name
    }
  }

  depends_on = [var.stages]
}

# Service user the pipeline authenticates as (key-pair auth).
resource "snowflake_service_user" "this" {
  name              = var.service_user_name
  comment           = var.service_user_comment
  default_warehouse = var.warehouse_name
  default_role      = snowflake_account_role.this.name
  default_namespace = "${var.database_name}.${var.schema_name}"
  rsa_public_key    = var.pipeline_rsa_public_key
}

resource "snowflake_grant_account_role" "loader_to_svc_user" {
  role_name = snowflake_account_role.this.name
  user_name = snowflake_service_user.this.name
}
