import logging
from datetime import datetime
from typing import Any

from shopify_engine.shopify.bulk import (
    download_jsonl,
    reassemble_orders,
    start_orders_bulk_operation,
    wait_for_bulk_operation,
)
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.shopify.queries import ORDERS_INCREMENTAL_QUERY

logger = logging.getLogger(__name__)


def fetch_orders_paginated(
    client: ShopifyGraphQLClient, query_filter: str, limit: int | None = None
) -> list[dict[str, Any]]:
    orders: list[dict[str, Any]] = []
    cursor = None

    while True:
        data = client.execute(
            ORDERS_INCREMENTAL_QUERY, {"cursor": cursor, "queryFilter": query_filter}
        )
        connection = data["orders"]

        for edge in connection["edges"]:
            node = edge["node"]
            line_items_connection = node["lineItems"]
            if line_items_connection["pageInfo"]["hasNextPage"]:
                logger.warning(
                    "Order %s has >250 line items; extra line items were not fetched.",
                    node["id"],
                )
            node["lineItems"] = [e["node"] for e in line_items_connection["edges"]]
            orders.append(node)
            if limit is not None and len(orders) >= limit:
                return orders

        if not connection["pageInfo"]["hasNextPage"]:
            break
        cursor = connection["pageInfo"]["endCursor"]

    return orders


def extract_backfill(
    client: ShopifyGraphQLClient, limit: int | None = None
) -> list[dict[str, Any]]:
    if limit is not None:
        # Small test pull: skip the async bulk operation and just page directly.
        return fetch_orders_paginated(client, query_filter="", limit=limit)

    start_orders_bulk_operation(client)
    url, object_count = wait_for_bulk_operation(client)
    logger.info("Bulk backfill completed: %d objects", object_count)
    if url is None:
        return []
    return reassemble_orders(download_jsonl(url))


def extract_incremental(
    client: ShopifyGraphQLClient, since: datetime, limit: int | None = None
) -> list[dict[str, Any]]:
    query_filter = f"updated_at:>='{since.isoformat()}'"
    return fetch_orders_paginated(client, query_filter=query_filter, limit=limit)


def max_updated_at(orders: list[dict[str, Any]]) -> datetime | None:
    if not orders:
        return None
    return max(datetime.fromisoformat(o["updatedAt"]) for o in orders)
