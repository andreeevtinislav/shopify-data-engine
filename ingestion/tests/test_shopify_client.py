import responses

from shopify_engine.config import Settings
from shopify_engine.shopify.client import ShopifyGraphQLClient, ShopifyGraphQLError

GRAPHQL_URL = "https://test-store.myshopify.com/admin/api/2025-10/graphql.json"


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


def _cost_extensions(available: float = 950) -> dict:
    return {
        "cost": {
            "requestedQueryCost": 10,
            "throttleStatus": {
                "maximumAvailable": 1000,
                "currentlyAvailable": available,
                "restoreRate": 50,
            },
        }
    }


@responses.activate
def test_execute_returns_data_on_success():
    responses.add(
        responses.POST,
        GRAPHQL_URL,
        json={"data": {"orders": {"edges": []}}, "extensions": _cost_extensions()},
        status=200,
    )

    client = ShopifyGraphQLClient(_settings())
    data = client.execute("query { orders { edges { node { id } } } }")

    assert data == {"orders": {"edges": []}}


@responses.activate
def test_execute_retries_on_throttled_error(monkeypatch):
    monkeypatch.setattr("shopify_engine.shopify.client.time.sleep", lambda _: None)

    responses.add(
        responses.POST,
        GRAPHQL_URL,
        json={
            "errors": [{"message": "Throttled", "extensions": {"code": "THROTTLED"}}],
            "extensions": _cost_extensions(available=5),
        },
        status=200,
    )
    responses.add(
        responses.POST,
        GRAPHQL_URL,
        json={"data": {"orders": {"edges": []}}, "extensions": _cost_extensions()},
        status=200,
    )

    client = ShopifyGraphQLClient(_settings())
    data = client.execute("query { orders { edges { node { id } } } }")

    assert data == {"orders": {"edges": []}}
    assert len(responses.calls) == 2


@responses.activate
def test_execute_raises_on_non_throttled_graphql_error(monkeypatch):
    monkeypatch.setattr("shopify_engine.shopify.client.time.sleep", lambda _: None)

    responses.add(
        responses.POST,
        GRAPHQL_URL,
        json={"errors": [{"message": "Field does not exist"}]},
        status=200,
    )

    client = ShopifyGraphQLClient(_settings())
    try:
        client.execute("query { bogus }")
        assert False, "expected ShopifyGraphQLError"
    except ShopifyGraphQLError:
        pass
