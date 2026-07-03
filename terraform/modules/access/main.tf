locals {
  roles = { for r in var.roles : r.name => r }

  # "<role>.<database>" -> distinct databases the role needs USAGE on.
  role_databases = merge([
    for r in var.roles : {
      for db in distinct([for g in r.grants : g.database]) :
      "${r.name}.${db}" => { role = r.name, database = db }
    }
  ]...)

  # "<role>.<database>.<schema>" -> schema-level grant (USAGE for read, ALL for readwrite).
  role_grants = merge([
    for r in var.roles : {
      for g in r.grants :
      "${r.name}.${g.database}.${g.schema}" => merge(g, { role = r.name })
    }
  ]...)
  role_grants_read      = { for k, g in local.role_grants : k => g if g.privilege == "read" }
  role_grants_readwrite = { for k, g in local.role_grants : k => g if g.privilege == "readwrite" }

  # "<role>.<database>.<schema>.<object_type>" -> grant+object_type (current-object grants).
  role_grant_objects = merge([
    for k, g in local.role_grants : {
      for ot in g.object_types : "${k}.${ot}" => merge(g, { object_type = ot })
    }
  ]...)
  role_grant_objects_read      = { for k, g in local.role_grant_objects : k => g if g.privilege == "read" }
  role_grant_objects_readwrite = { for k, g in local.role_grant_objects : k => g if g.privilege == "readwrite" }

  # FUTURE grants only make sense for TABLES/VIEWS (matches pre-refactor behavior,
  # which never had a "future stages" grant).
  role_grant_objects_future_read = {
    for k, g in local.role_grant_objects_read : k => g if contains(["TABLES", "VIEWS"], g.object_type)
  }
  role_grant_objects_future_readwrite = {
    for k, g in local.role_grant_objects_readwrite : k => g if contains(["TABLES", "VIEWS"], g.object_type)
  }
}

resource "snowflake_account_role" "this" {
  for_each = local.roles

  name    = each.value.name
  comment = try(each.value.comment, null)
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  for_each = local.roles

  account_role_name = snowflake_account_role.this[each.key].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.warehouse_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  for_each = local.role_databases

  account_role_name = snowflake_account_role.this[each.value.role].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = each.value.database
  }
}

# read tier: schema-level USAGE only.
resource "snowflake_grant_privileges_to_account_role" "schema_usage" {
  for_each = local.role_grants_read

  account_role_name = snowflake_account_role.this[each.value.role].name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = var.schema_fully_qualified_names["${each.value.database}.${each.value.schema}"]
  }
}

# readwrite tier: schema-level ALL PRIVILEGES. Kept as resource name "schema_all"
# (unchanged from the pre-refactor module) so the existing SHOPIFY_LOADER_ROLE
# grant maps onto it with a trivial for_each-ification via moved{}.
resource "snowflake_grant_privileges_to_account_role" "schema_all" {
  for_each = local.role_grants_readwrite

  account_role_name = snowflake_account_role.this[each.value.role].name
  all_privileges    = true
  on_schema {
    schema_name = var.schema_fully_qualified_names["${each.value.database}.${each.value.schema}"]
  }
}

# current objects, read tier: SELECT only.
resource "snowflake_grant_privileges_to_account_role" "schema_objects_current_select" {
  for_each = local.role_grant_objects_read

  account_role_name = snowflake_account_role.this[each.value.role].name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = each.value.object_type
      in_schema          = var.schema_fully_qualified_names["${each.value.database}.${each.value.schema}"]
    }
  }

  depends_on = [var.tables, var.stages]
}

# current objects, readwrite tier: ALL PRIVILEGES.
resource "snowflake_grant_privileges_to_account_role" "schema_objects_current_all" {
  for_each = local.role_grant_objects_readwrite

  account_role_name = snowflake_account_role.this[each.value.role].name
  all_privileges    = true
  on_schema_object {
    all {
      object_type_plural = each.value.object_type
      in_schema          = var.schema_fully_qualified_names["${each.value.database}.${each.value.schema}"]
    }
  }

  depends_on = [var.tables, var.stages]
}

# future objects (TABLES/VIEWS only), read tier.
resource "snowflake_grant_privileges_to_account_role" "schema_objects_future_select" {
  for_each = local.role_grant_objects_future_read

  account_role_name = snowflake_account_role.this[each.value.role].name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = each.value.object_type
      in_schema          = var.schema_fully_qualified_names["${each.value.database}.${each.value.schema}"]
    }
  }
}

# future objects (TABLES/VIEWS only), readwrite tier.
resource "snowflake_grant_privileges_to_account_role" "schema_objects_future_all" {
  for_each = local.role_grant_objects_future_readwrite

  account_role_name = snowflake_account_role.this[each.value.role].name
  all_privileges    = true
  on_schema_object {
    future {
      object_type_plural = each.value.object_type
      in_schema          = var.schema_fully_qualified_names["${each.value.database}.${each.value.schema}"]
    }
  }
}

resource "snowflake_service_user" "this" {
  for_each = local.roles

  name              = each.value.service_user.name
  comment           = try(each.value.service_user.comment, null)
  default_warehouse = var.warehouse_name
  default_role      = snowflake_account_role.this[each.key].name
  default_namespace = "${each.value.service_user.default_database}.${var.schema_names["${each.value.service_user.default_database}.${each.value.service_user.default_schema}"]}"
  rsa_public_key    = var.service_user_rsa_public_keys[each.key]
}

resource "snowflake_grant_account_role" "svc_user" {
  for_each = local.roles

  role_name = snowflake_account_role.this[each.key].name
  user_name = snowflake_service_user.this[each.key].name
}
