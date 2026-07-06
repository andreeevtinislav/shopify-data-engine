import json
import time
from collections.abc import Iterable, Iterator
from typing import Any

import requests

from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.shopify.queries import (
    CURRENT_BULK_OPERATION_QUERY,
    ORDERS_BULK_QUERY,
    PRODUCTS_BULK_QUERY,
    START_BULK_OPERATION_MUTATION,
)

DEFAULT_POLL_INTERVAL_SECONDS = 15
DEFAULT_TIMEOUT_SECONDS = 3600

TERMINAL_FAILURE_STATUSES = {"FAILED", "CANCELED", "EXPIRED"}


class BulkOperationError(RuntimeError):
    pass


def start_bulk_operation(client: ShopifyGraphQLClient, query: str) -> str:
    data = client.execute(START_BULK_OPERATION_MUTATION, {"query": query})
    result = data["bulkOperationRunQuery"]
    if result["userErrors"]:
        raise BulkOperationError(str(result["userErrors"]))
    return result["bulkOperation"]["id"]


def start_orders_bulk_operation(client: ShopifyGraphQLClient) -> str:
    return start_bulk_operation(client, ORDERS_BULK_QUERY)


def start_products_bulk_operation(client: ShopifyGraphQLClient) -> str:
    return start_bulk_operation(client, PRODUCTS_BULK_QUERY)


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


def _reassemble(lines: Iterable[dict[str, Any]], child_field: str) -> list[dict[str, Any]]:
    """Bulk operation JSONL flattens connection fields (e.g. lineItems, variants)
    into separate lines linked to their parent via `__parentId`. Other list fields
    stay nested inline on the parent line as-is. Regroups everything back into
    one JSON object per parent.
    """
    parents: dict[str, dict[str, Any]] = {}
    parent_ids_in_sequence: list[str] = []

    for obj in lines:
        parent_id = obj.get("__parentId")
        if parent_id is None:
            parent = dict(obj)
            parent[child_field] = []
            parents[parent["id"]] = parent
            parent_ids_in_sequence.append(parent["id"])
            continue

        parent = parents.get(parent_id)
        if parent is None:
            # Bulk JSONL is parent-first, so this shouldn't happen; skip defensively
            # rather than crash the whole backfill over one malformed line.
            continue
        parent[child_field].append({k: v for k, v in obj.items() if k != "__parentId"})

    return [parents[parent_id] for parent_id in parent_ids_in_sequence]


def reassemble_orders(lines: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    return _reassemble(lines, child_field="lineItems")


def reassemble_products(lines: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    return _reassemble(lines, child_field="variants")
