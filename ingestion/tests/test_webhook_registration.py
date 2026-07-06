import json

import responses

from shopify_engine.config import Settings
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.shopify.webhooks import (
    WEBHOOK_TOPICS,
    WebhookRegistrationError,
    register_all,
    register_webhook,
)

GRAPHQL_URL = "https://test-store.myshopify.com/admin/api/2025-10/graphql.json"
CALLBACK_URL = "https://example.execute-api.eu-west-1.amazonaws.com/webhooks/shopify"


def _settings() -> Settings:
    return Settings(
        shopify_shop_domain="test-store.myshopify.com",
        shopify_access_token="shpat_test",
        shopify_api_version="2025-10",
        snowflake_account="acct",
        snowflake_user="user",
        snowflake_password="pw",
        snowflake_private_key_path=None,
        snowflake_warehouse="wh",
        snowflake_database="db",
        snowflake_schema="RAW",
        snowflake_role="role",
    )


def _subscriptions_response(edges: list[dict]) -> dict:
    return {"data": {"webhookSubscriptions": {"edges": edges}}}


def _create_response(errors: list | None = None) -> dict:
    return {
        "data": {
            "webhookSubscriptionCreate": {
                "webhookSubscription": {"id": "gid://shopify/WebhookSubscription/1"},
                "userErrors": errors or [],
            }
        }
    }


@responses.activate
def test_register_all_registers_every_topic_when_none_exist():
    responses.add(responses.POST, GRAPHQL_URL, json=_subscriptions_response([]), status=200)
    for _ in WEBHOOK_TOPICS:
        responses.add(responses.POST, GRAPHQL_URL, json=_create_response(), status=200)

    register_all(_settings(), CALLBACK_URL)

    create_calls = responses.calls[1:]
    assert len(create_calls) == len(WEBHOOK_TOPICS)

    sent_topics = {}
    for call in create_calls:
        variables = json.loads(call.request.body)["variables"]
        sent_topics[variables["topic"]] = variables

    assert set(sent_topics) == set(WEBHOOK_TOPICS)
    assert sent_topics["ORDERS_CREATE"]["callbackUrl"] == CALLBACK_URL


@responses.activate
def test_register_all_skips_topic_already_registered_for_callback_url():
    existing_edges = [
        {
            "node": {
                "id": "gid://shopify/WebhookSubscription/9",
                "topic": "ORDERS_CREATE",
                "endpoint": {"callbackUrl": CALLBACK_URL},
            }
        }
    ]
    responses.add(
        responses.POST, GRAPHQL_URL, json=_subscriptions_response(existing_edges), status=200
    )
    for _ in range(len(WEBHOOK_TOPICS) - 1):
        responses.add(responses.POST, GRAPHQL_URL, json=_create_response(), status=200)

    register_all(_settings(), CALLBACK_URL)

    create_calls = responses.calls[1:]
    assert len(create_calls) == len(WEBHOOK_TOPICS) - 1
    sent_topics = {json.loads(c.request.body)["variables"]["topic"] for c in create_calls}
    assert "ORDERS_CREATE" not in sent_topics


@responses.activate
def test_register_webhook_raises_on_user_errors():
    responses.add(
        responses.POST,
        GRAPHQL_URL,
        json=_create_response(errors=[{"field": ["topic"], "message": "already exists"}]),
        status=200,
    )

    client = ShopifyGraphQLClient(_settings())
    try:
        register_webhook(client, "ORDERS_CREATE", CALLBACK_URL)
        assert False, "expected WebhookRegistrationError"
    except WebhookRegistrationError:
        pass
