import json
import time
from collections.abc import Iterable, Iterator
from typing import Any

import requests

from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.shopify.queries import (
    CURRENT_BULK_OPERATION_QUERY,
    ORDERS_BULK_QUERY,
    START_BULK_OPERATION_MUTATION,
)

DEFAULT_POLL_INTERVAL_SECONDS = 15
DEFAULT_TIMEOUT_SECONDS = 3600

TERMINAL_FAILURE_STATUSES = {"FAILED", "CANCELED", "EXPIRED"}


class BulkOperationError(RuntimeError):
    pass


def start_orders_bulk_operation(client: ShopifyGraphQLClient) -> str:
    data = client.execute(START_BULK_OPERATION_MUTATION, {"query": ORDERS_BULK_QUERY})
    result = data["bulkOperationRunQuery"]
    if result["userErrors"]:
        raise BulkOperationError(str(result["userErrors"]))
    return result["bulkOperation"]["id"]


def wait_for_bulk_operation(
    client: ShopifyGraphQLClient,
    poll_interval: int = DEFAULT_POLL_INTERVAL_SECONDS,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> tuple[str | None, int]:
    """Poll currentBulkOperation until it completes. Returns (download_url, object_count).

    download_url is None if the operation completed with zero objects (Shopify
    omits `url` in that case, e.g. an empty store).
    """
    elapsed = 0
    while elapsed <= timeout:
        data = client.execute(CURRENT_BULK_OPERATION_QUERY)
        op = data["currentBulkOperation"]
        if op is None:
            raise BulkOperationError("No bulk operation found while polling")

        status = op["status"]
        if status == "COMPLETED":
            object_count = int(op.get("objectCount") or 0)
            return op.get("url"), object_count
        if status in TERMINAL_FAILURE_STATUSES:
            raise BulkOperationError(
                f"Bulk operation ended with status={status} errorCode={op.get('errorCode')}"
            )

        time.sleep(poll_interval)
        elapsed += poll_interval

    raise BulkOperationError(f"Bulk operation did not complete within {timeout}s")


def download_jsonl(url: str) -> Iterator[dict[str, Any]]:
    with requests.get(url, stream=True, timeout=300) as response:
        response.raise_for_status()
        for line in response.iter_lines(decode_unicode=True):
            if line:
                yield json.loads(line)


def reassemble_orders(lines: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    """Bulk operation JSONL flattens connection fields (e.g. lineItems) into
    separate lines linked to their parent order via `__parentId`. Non-connection
    list fields (e.g. refunds) stay nested inline on the order line as-is.
    Regroups everything back into one JSON object per order.
    """
    orders: dict[str, dict[str, Any]] = {}
    order_ids_in_sequence: list[str] = []

    for obj in lines:
        parent_id = obj.get("__parentId")
        if parent_id is None:
            order = dict(obj)
            order["lineItems"] = []
            orders[order["id"]] = order
            order_ids_in_sequence.append(order["id"])
            continue

        parent = orders.get(parent_id)
        if parent is None:
            # Bulk JSONL is parent-first, so this shouldn't happen; skip defensively
            # rather than crash the whole backfill over one malformed line.
            continue
        parent["lineItems"].append({k: v for k, v in obj.items() if k != "__parentId"})

    return [orders[order_id] for order_id in order_ids_in_sequence]
