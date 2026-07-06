import logging
from datetime import datetime
from typing import Any

from shopify_engine.shopify.bulk import (
    download_jsonl,
    reassemble_products,
    start_products_bulk_operation,
    wait_for_bulk_operation,
)
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.shopify.queries import PRODUCTS_INCREMENTAL_QUERY

logger = logging.getLogger(__name__)


def fetch_products_paginated(
    client: ShopifyGraphQLClient, query_filter: str, limit: int | None = None
) -> list[dict[str, Any]]:
    products: list[dict[str, Any]] = []
    cursor = None

    while True:
        data = client.execute(
            PRODUCTS_INCREMENTAL_QUERY, {"cursor": cursor, "queryFilter": query_filter}
        )
        connection = data["products"]

        for edge in connection["edges"]:
            node = edge["node"]
            variants_connection = node["variants"]
            if variants_connection["pageInfo"]["hasNextPage"]:
                logger.warning(
                    "Product %s has >100 variants; extra variants were not fetched.",
                    node["id"],
                )
            node["variants"] = [e["node"] for e in variants_connection["edges"]]
            products.append(node)
            if limit is not None and len(products) >= limit:
                return products

        if not connection["pageInfo"]["hasNextPage"]:
            break
        cursor = connection["pageInfo"]["endCursor"]

    return products


def extract_backfill(
    client: ShopifyGraphQLClient, limit: int | None = None
) -> list[dict[str, Any]]:
    if limit is not None:
        # Small test pull: skip the async bulk operation and just page directly.
        return fetch_products_paginated(client, query_filter="", limit=limit)

    start_products_bulk_operation(client)
    url, object_count = wait_for_bulk_operation(client)
    logger.info("Bulk backfill completed: %d objects", object_count)
    if url is None:
        return []
    return reassemble_products(download_jsonl(url))


def extract_incremental(
    client: ShopifyGraphQLClient, since: datetime, limit: int | None = None
) -> list[dict[str, Any]]:
    query_filter = f"updated_at:>='{since.isoformat()}'"
    return fetch_products_paginated(client, query_filter=query_filter, limit=limit)


def max_updated_at(products: list[dict[str, Any]]) -> datetime | None:
    if not products:
        return None
    return max(datetime.fromisoformat(p["updatedAt"]) for p in products)
