import logging
import tempfile
from datetime import timedelta
from pathlib import Path

from shopify_engine.config import Settings
from shopify_engine.extractors import orders as orders_extractor
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.snowflake import loader
from shopify_engine.snowflake.connection import get_connection
from shopify_engine.sync import state

logger = logging.getLogger(__name__)

TMP_DIR = Path(tempfile.gettempdir()) / "shopify_engine"

# Incremental syncs re-pull a small overlap window before the last watermark;
# safe because loading is idempotent (MERGE-upsert by order id).
INCREMENTAL_OVERLAP = timedelta(minutes=10)


def run_backfill(settings: Settings, object_name: str = "orders", limit: int | None = None) -> int:
    client = ShopifyGraphQLClient(settings)
    conn = get_connection(settings)
    try:
        state.start_run(conn, object_name)
        fetched_orders = orders_extractor.extract_backfill(client, limit=limit)
        rows = loader.load_orders(conn, fetched_orders, TMP_DIR)
        watermark = orders_extractor.max_updated_at(fetched_orders)
        state.complete_run(conn, object_name, watermark, rows)
        logger.info("Backfill complete: %d orders loaded", rows)
        return rows
    except Exception:
        state.fail_run(conn, object_name)
        raise
    finally:
        conn.close()


def run_incremental(settings: Settings, object_name: str = "orders", limit: int | None = None) -> int:
    client = ShopifyGraphQLClient(settings)
    conn = get_connection(settings)
    try:
        watermark = state.get_watermark(conn, object_name)
        if watermark is None:
            raise RuntimeError(
                f"No watermark found for '{object_name}'. Run --mode backfill first."
            )

        state.start_run(conn, object_name)
        since = watermark - INCREMENTAL_OVERLAP
        fetched_orders = orders_extractor.extract_incremental(client, since, limit=limit)
        rows = loader.load_orders(conn, fetched_orders, TMP_DIR)
        new_watermark = orders_extractor.max_updated_at(fetched_orders)
        state.complete_run(conn, object_name, new_watermark, rows)
        logger.info("Incremental sync complete: %d orders loaded", rows)
        return rows
    except Exception:
        state.fail_run(conn, object_name)
        raise
    finally:
        conn.close()
