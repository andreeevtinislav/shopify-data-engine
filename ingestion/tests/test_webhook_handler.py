import base64
import hashlib
import hmac
import json
from unittest.mock import MagicMock

from shopify_engine.webhook.handler import _process_event

WEBHOOK_SECRET = "test-webhook-secret"


def _sign(body: bytes) -> str:
    digest = hmac.new(WEBHOOK_SECRET.encode("utf-8"), body, hashlib.sha256).digest()
    return base64.b64encode(digest).decode("utf-8")


def _event(body: dict, topic: str, *, sign: bool = True) -> dict:
    raw = json.dumps(body).encode("utf-8")
    headers = {"X-Shopify-Topic": topic}
    if sign:
        headers["X-Shopify-Hmac-Sha256"] = _sign(raw)
    return {"body": raw.decode("utf-8"), "headers": headers, "isBase64Encoded": False}


def _conn_factory(conn: MagicMock):
    return lambda: conn


def test_valid_order_create_loads_order_and_returns_200():
    # Shopify's default webhook payload for orders/* is REST-shaped (numeric
    # `id`), not ORDER_FIELDS-shaped — the handler always re-fetches via GraphQL.
    webhook_body = {"id": 1, "name": "#1001"}
    event = _event(webhook_body, "orders/create")
    conn = MagicMock()
    conn.cursor.return_value.fetchone.return_value = (1, 0)
    client = MagicMock()
    client.execute.return_value = {"order": {"id": "gid://shopify/Order/1", "name": "#1001"}}

    response = _process_event(event, WEBHOOK_SECRET, client, _conn_factory(conn))

    assert response == {"statusCode": 200}
    client.execute.assert_called_once()
    args, kwargs = client.execute.call_args
    assert args[1] == {"id": "gid://shopify/Order/1"}
    executed_sql = [c.args[0] for c in conn.cursor.return_value.execute.call_args_list]
    assert any("MERGE INTO" in sql for sql in executed_sql)


def test_invalid_hmac_returns_401_and_never_opens_connection():
    order = {"id": "gid://shopify/Order/1"}
    event = _event(order, "orders/create", sign=False)
    event["headers"]["X-Shopify-Hmac-Sha256"] = "not-a-real-signature"
    conn_factory = MagicMock(side_effect=AssertionError("connection should not be opened"))

    response = _process_event(event, WEBHOOK_SECRET, MagicMock(), conn_factory)

    assert response == {"statusCode": 401}
    conn_factory.assert_not_called()


def test_refund_create_refetches_order_before_merge():
    refund_body = {"id": 555, "order_id": 999}
    event = _event(refund_body, "refunds/create")
    conn = MagicMock()
    conn.cursor.return_value.fetchone.return_value = (0, 1)
    client = MagicMock()
    client.execute.return_value = {"order": {"id": "gid://shopify/Order/999"}}

    response = _process_event(event, WEBHOOK_SECRET, client, _conn_factory(conn))

    assert response == {"statusCode": 200}
    client.execute.assert_called_once()
    args, kwargs = client.execute.call_args
    assert args[1] == {"id": "gid://shopify/Order/999"}


def test_shopify_refetch_failure_returns_500():
    refund_body = {"id": 555, "order_id": 999}
    event = _event(refund_body, "refunds/create")
    client = MagicMock()
    client.execute.side_effect = RuntimeError("Shopify API down")
    conn_factory = MagicMock(side_effect=AssertionError("connection should not be opened"))

    response = _process_event(event, WEBHOOK_SECRET, client, conn_factory)

    assert response == {"statusCode": 500}


def test_snowflake_failure_returns_500():
    webhook_body = {"id": 1}
    event = _event(webhook_body, "orders/create")
    conn = MagicMock()
    conn.cursor.return_value.execute.side_effect = RuntimeError("snowflake down")
    client = MagicMock()
    client.execute.return_value = {"order": {"id": "gid://shopify/Order/1"}}

    response = _process_event(event, WEBHOOK_SECRET, client, _conn_factory(conn))

    assert response == {"statusCode": 500}
    conn.close.assert_called_once()


def test_unrecognized_topic_returns_400():
    event = _event({"id": "gid://shopify/Order/1"}, "products/update")
    conn_factory = MagicMock(side_effect=AssertionError("connection should not be opened"))

    response = _process_event(event, WEBHOOK_SECRET, MagicMock(), conn_factory)

    assert response == {"statusCode": 400}


def test_missing_order_id_returns_400():
    event = _event({"name": "no id here"}, "orders/create")
    conn_factory = MagicMock(side_effect=AssertionError("connection should not be opened"))

    response = _process_event(event, WEBHOOK_SECRET, MagicMock(), conn_factory)

    assert response == {"statusCode": 400}
