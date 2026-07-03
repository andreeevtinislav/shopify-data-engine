resource "snowflake_table" "shopify_orders_json" {
  database = snowflake_database.shopify_data.name
  schema   = snowflake_schema.raw.name
  name     = "SHOPIFY_ORDERS_JSON"
  comment  = "Raw Shopify order payloads (GraphQL Admin API), upserted by Shopify order id."

  column {
    name     = "_SHOPIFY_ORDER_ID"
    type     = "STRING"
    nullable = false
  }

  column {
    name     = "PAYLOAD"
    type     = "VARIANT"
    nullable = false
  }

  column {
    name = "_LOADED_AT"
    type = "TIMESTAMP_NTZ"

    default {
      expression = "CURRENT_TIMESTAMP()"
    }
  }

  column {
    name     = "_SOURCE_FILE"
    type     = "STRING"
    nullable = true
  }

  # No primary_key constraint: Snowflake doesn't enforce uniqueness on it (informational
  # only) and the block is deprecated in the provider. Uniqueness on _SHOPIFY_ORDER_ID is
  # actually enforced by the pipeline's MERGE-upsert logic (see snowflake/loader.py).
}

resource "snowflake_table" "sync_state" {
  database = snowflake_database.shopify_data.name
  schema   = snowflake_schema.raw.name
  name     = "_SYNC_STATE"
  comment  = "Watermark/state tracking per synced object (e.g. orders) for backfill/incremental runs."

  column {
    name     = "OBJECT_NAME"
    type     = "STRING"
    nullable = false
  }

  column {
    name     = "LAST_WATERMARK"
    type     = "TIMESTAMP_NTZ"
    nullable = true
  }

  column {
    name     = "LAST_RUN_STARTED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = true
  }

  column {
    name     = "LAST_RUN_COMPLETED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = true
  }

  column {
    name     = "LAST_RUN_STATUS"
    type     = "STRING"
    nullable = true
  }

  column {
    name     = "RECORDS_PROCESSED"
    type     = "NUMBER"
    nullable = true
  }
}
