import gzip
import json
import time
import uuid
from pathlib import Path
from typing import Any

import snowflake.connector

STAGE_NAME = "SHOPIFY_STAGE"
ORDERS_TABLE = "SHOPIFY_ORDERS_JSON"

MERGE_ORDERS_SQL = f"""
MERGE INTO {ORDERS_TABLE} AS tgt
USING (
  SELECT
    $1:id::string AS shopify_order_id,
    $1 AS payload,
    METADATA$FILENAME AS source_file
  FROM @{STAGE_NAME}/{{staged_filename}}
) AS src
ON tgt._shopify_order_id = src.shopify_order_id
WHEN MATCHED THEN UPDATE SET
  tgt.payload = src.payload,
  tgt._loaded_at = CURRENT_TIMESTAMP(),
  tgt._source_file = src.source_file
WHEN NOT MATCHED THEN INSERT (_shopify_order_id, payload, _loaded_at, _source_file)
  VALUES (src.shopify_order_id, src.payload, CURRENT_TIMESTAMP(), src.source_file)
"""


def write_jsonl_gz(orders: list[dict[str, Any]], tmp_dir: Path) -> Path:
    tmp_dir.mkdir(parents=True, exist_ok=True)
    path = tmp_dir / f"orders_{int(time.time())}_{uuid.uuid4().hex[:8]}.jsonl.gz"
    with gzip.open(path, "wt", encoding="utf-8") as f:
        for order in orders:
            f.write(json.dumps(order))
            f.write("\n")
    return path


def put_to_stage(conn: snowflake.connector.SnowflakeConnection, local_path: Path) -> str:
    cursor = conn.cursor()
    try:
        # Already gzipped by write_jsonl_gz, so disable Snowflake's own compression.
        cursor.execute(
            f"PUT file://{local_path} @{STAGE_NAME} AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
        )
    finally:
        cursor.close()
    return local_path.name


def merge_orders_from_stage(
    conn: snowflake.connector.SnowflakeConnection, staged_filename: str
) -> int:
    cursor = conn.cursor()
    try:
        cursor.execute(MERGE_ORDERS_SQL.format(staged_filename=staged_filename))
        # MERGE returns one row: (rows inserted, rows updated).
        result = cursor.fetchone()
        return sum(result) if result else 0
    finally:
        cursor.close()


def remove_from_stage(conn: snowflake.connector.SnowflakeConnection, staged_filename: str) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(f"REMOVE @{STAGE_NAME}/{staged_filename}")
    finally:
        cursor.close()


def load_orders(
    conn: snowflake.connector.SnowflakeConnection,
    orders: list[dict[str, Any]],
    tmp_dir: Path,
) -> int:
    """Writes orders to a local gzipped JSONL file, stages it, MERGEs it into
    RAW.SHOPIFY_ORDERS_JSON (upsert by Shopify order id), then cleans up both
    the staged file and the local temp file. Returns rows affected.
    """
    if not orders:
        return 0

    local_path = write_jsonl_gz(orders, tmp_dir)
    try:
        staged_filename = put_to_stage(conn, local_path)
        try:
            return merge_orders_from_stage(conn, staged_filename)
        finally:
            remove_from_stage(conn, staged_filename)
    finally:
        local_path.unlink(missing_ok=True)
