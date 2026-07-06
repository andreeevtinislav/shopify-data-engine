import base64
import json
import logging
import os
import tempfile
from pathlib import Path
from typing import Any

import boto3

from shopify_engine.config import Settings
from shopify_engine.shopify import queries
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.snowflake import loader
from shopify_engine.snowflake.connection import get_connection
from shopify_engine.webhook.verify import verify_shopify_hmac

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)

# Lambda's only writable path; kept local to this module rather than importing
# orchestrator.TMP_DIR, which drags in unrelated extractor/watermark/state logic.
TMP_DIR = Path(tempfile.gettempdir()) / "shopify_engine"
PRIVATE_KEY_PATH = Path(tempfile.gettempdir()) / "snowflake_key.p8"

# Shopify has no way to deliver these pre-shaped as ORDER_FIELDS (confirmed
# against the live Admin API — WebhookSubscriptionInput has no payload-shaping
# field). Every topic's body is in Shopify's default JSON shape, so every
# topic is treated the same: pull the order id out of the delivered body,
# then re-fetch the full order via ORDER_BY_ID_QUERY. This keeps exactly one
# payload shape ever written to RAW, regardless of topic.
# Order-resource topics: default payload has the order's own numeric id at `id`.
ORDER_TOPICS = {"orders/create", "orders/updated", "orders/cancelled"}
# Refund-resource topic: default payload is Refund-shaped; the order id is at `order_id`.
REFUND_TOPICS = {"refunds/create"}

# Cached at module scope so a warm Lambda invocation skips the Secrets Manager
# round-trip; only a cold start pays for it.
_settings: Settings | None = None
_webhook_secret: str | None = None


def _load_secret(secret_id: str) -> str:
    return boto3.client("secretsmanager").get_secret_value(SecretId=secret_id)["SecretString"]


def _bootstrap() -> tuple[Settings, str]:
    global _settings, _webhook_secret
    if _settings is not None and _webhook_secret is not None:
        return _settings, _webhook_secret

    access_token = _load_secret(os.environ["SHOPIFY_ACCESS_TOKEN_SECRET_ID"])
    webhook_secret = _load_secret(os.environ["SHOPIFY_WEBHOOK_SECRET_SECRET_ID"])
    private_key_pem = _load_secret(os.environ["SNOWFLAKE_PRIVATE_KEY_SECRET_ID"])

    PRIVATE_KEY_PATH.write_text(private_key_pem)
    # connection.py/config.py need zero changes: they just see a normal env var
    # and file path, exactly as they do today running under ECS.
    os.environ["SHOPIFY_ACCESS_TOKEN"] = access_token
    os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"] = str(PRIVATE_KEY_PATH)

    _settings = Settings.from_env()
    _webhook_secret = webhook_secret
    return _settings, _webhook_secret


def _get_header(headers: dict[str, str], name: str) -> str | None:
    lname = name.lower()
    for key, value in headers.items():
        if key.lower() == lname:
            return value
    return None


def _response(status_code: int) -> dict[str, Any]:
    return {"statusCode": status_code}


def _extract_order_id(topic: str, body: dict[str, Any]) -> Any | None:
    if topic in ORDER_TOPICS:
        return body.get("id")
    if topic in REFUND_TOPICS:
        return body.get("order_id")
    return None


def _extract_order(
    topic: str, body: dict[str, Any], client: ShopifyGraphQLClient
) -> dict[str, Any] | None:
    order_id = _extract_order_id(topic, body)
    if not order_id:
        return None
    gid = f"gid://shopify/Order/{order_id}"
    data = client.execute(queries.ORDER_BY_ID_QUERY, {"id": gid})
    return data.get("order")


def _process_event(
    event: dict[str, Any],
    webhook_secret: str,
    client: ShopifyGraphQLClient,
    conn_factory: Any,
) -> dict[str, Any]:
    raw_body = event.get("body") or ""
    body_bytes = (
        base64.b64decode(raw_body) if event.get("isBase64Encoded") else raw_body.encode("utf-8")
    )

    headers = event.get("headers") or {}
    hmac_header = _get_header(headers, "X-Shopify-Hmac-Sha256")
    if not verify_shopify_hmac(body_bytes, hmac_header, webhook_secret):
        logger.warning("Rejected webhook: invalid HMAC")
        return _response(401)

    topic = _get_header(headers, "X-Shopify-Topic") or ""
    try:
        parsed = json.loads(body_bytes)
    except ValueError:
        logger.warning("Rejected webhook: invalid JSON body for topic=%s", topic)
        return _response(400)

    try:
        order = _extract_order(topic, parsed, client)
    except Exception:
        # Transient Shopify-side failure during the refund->order re-fetch — let
        # Shopify retry rather than treating it as a permanent rejection.
        logger.exception("Failed to resolve order for topic=%s", topic)
        return _response(500)

    if not order or not order.get("id"):
        logger.warning("Rejected webhook: no resolvable order (topic=%s)", topic)
        return _response(400)

    # Connection is only opened once we know we actually have something to write —
    # invalid HMAC / bad topic / unresolvable order all short-circuit above it.
    conn = conn_factory()
    try:
        loader.load_orders(conn, [order], TMP_DIR)
    except Exception:
        logger.exception("Failed to load order %s into Snowflake", order.get("id"))
        return _response(500)
    finally:
        conn.close()

    return _response(200)


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    settings, webhook_secret = _bootstrap()
    client = ShopifyGraphQLClient(settings)
    return _process_event(event, webhook_secret, client, conn_factory=lambda: get_connection(settings))
