import logging
import tempfile
from datetime import timedelta
from pathlib import Path

from shopify_engine.config import Settings
from shopify_engine.extractors import orders as orders_extractor
from shopify_engine.extractors import products as products_extractor
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.snowflake import loader
from shopify_engine.snowflake.connection import get_connection
from shopify_engine.sync import state

logger = logging.getLogger(__name__)

TMP_DIR = Path(tempfile.gettempdir()) / "shopify_engine"

# Incremental syncs re-pull a small overlap window before the last watermark;
# safe because loading is idempotent (MERGE-upsert by object id).
INCREMENTAL_OVERLAP = timedelta(minutes=10)

# Each synced object needs matching extractor (backfill/incremental/watermark)
# and loader (stage + MERGE) implementations; object_name also keys _SYNC_STATE.
_EXTRACTORS = {
    "orders": orders_extractor,
    "products": products_extractor,
}
_LOADERS = {
    "orders": loader.load_orders,
    "products": loader.load_products,
}


def run_backfill(settings: Settings, object_name: str = "orders", limit: int | None = None) -> int:
    extractor = _EXTRACTORS[object_name]
    load_fn = _LOADERS[object_name]
    client = ShopifyGraphQLClient(settings)
    conn = get_connection(settings)
    try:
        state.start_run(conn, object_name)
        fetched = extractor.extract_backfill(client, limit=limit)
        rows = load_fn(conn, fetched, TMP_DIR)
        watermark = extractor.max_updated_at(fetched)
        state.complete_run(conn, object_name, watermark, rows)
        logger.info("Backfill complete: %d %s loaded", rows, object_name)
        return rows
    except Exception:
        state.fail_run(conn, object_name)
        raise
    finally:
        conn.close()


def run_incremental(settings: Settings, object_name: str = "orders", limit: int | None = None) -> int:
    extractor = _EXTRACTORS[object_name]
    load_fn = _LOADERS[object_name]
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
        fetched = extractor.extract_incremental(client, since, limit=limit)
        rows = load_fn(conn, fetched, TMP_DIR)
        new_watermark = extractor.max_updated_at(fetched)
        state.complete_run(conn, object_name, new_watermark, rows)
        logger.info("Incremental sync complete: %d %s loaded", rows, object_name)
        return rows
    except Exception:
        state.fail_run(conn, object_name)
        raise
    finally:
        conn.close()
