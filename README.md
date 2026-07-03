# shopify-data-engine

Custom pipeline that loads Shopify data into Snowflake. Personal project, structured as if each top-level folder were its own repo:

- **[`terraform/`](terraform/README.md)** — Snowflake infrastructure as code (warehouse, database, schema, tables, stage, roles). Provision this first.
- **[`ingestion/`](ingestion/README.md)** — the Python pipeline that extracts Shopify orders and loads them into the Snowflake tables `terraform/` creates.

v1 covers orders and line items only, landed as raw JSON — no transformation layer yet (that's a future dbt project, likely its own top-level folder later).
