resource "snowflake_warehouse" "shopify_wh" {
  name                = var.warehouse_name
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = "true"
  initially_suspended = true
  comment             = "Compute for the Shopify ingestion pipeline."
}

resource "snowflake_database" "shopify_data" {
  name    = var.database_name
  comment = "Landing zone for raw Shopify data."
}

resource "snowflake_schema" "raw" {
  database = snowflake_database.shopify_data.name
  name     = var.raw_schema_name
  comment  = "Raw, untransformed Shopify API payloads. Source schema for the future dbt project."
}

# Internal stage used as the landing zone for PUT-uploaded JSONL files before
# they're MERGEd into RAW.SHOPIFY_ORDERS_JSON. The inline JSON file_format means
# loader.py's SELECT ... FROM @stage doesn't need to specify a format at query time.
resource "snowflake_stage_internal" "shopify_stage" {
  name     = "SHOPIFY_STAGE"
  database = snowflake_database.shopify_data.name
  schema   = snowflake_schema.raw.name
  comment  = "Landing zone for gzipped Shopify JSONL files before MERGE into RAW tables."

  file_format {
    json {
      compression = "AUTO"
    }
  }
}
