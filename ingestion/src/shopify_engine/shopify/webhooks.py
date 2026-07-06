import logging
from typing import Any

import click

from shopify_engine.config import Settings
from shopify_engine.shopify.client import ShopifyGraphQLClient
from shopify_engine.shopify.queries import (
    WEBHOOK_SUBSCRIPTION_CREATE_MUTATION,
    WEBHOOK_SUBSCRIPTIONS_QUERY,
)

logger = logging.getLogger(__name__)

# Every topic delivers Shopify's default JSON payload shape — there's no way
# to have Shopify deliver these pre-shaped as ORDER_FIELDS (confirmed against
# the live Admin API; see the comment on WEBHOOK_SUBSCRIPTION_CREATE_MUTATION
# in queries.py). The webhook handler re-fetches the full order via
# ORDER_BY_ID_QUERY for every topic, regardless of shape.
WEBHOOK_TOPICS = ["ORDERS_CREATE", "ORDERS_UPDATED", "ORDERS_CANCELLED", "REFUNDS_CREATE"]


class WebhookRegistrationError(RuntimeError):
    pass


def list_existing_subscriptions(client: ShopifyGraphQLClient) -> list[dict[str, Any]]:
    data = client.execute(WEBHOOK_SUBSCRIPTIONS_QUERY, {"topics": WEBHOOK_TOPICS})
    return [edge["node"] for edge in data["webhookSubscriptions"]["edges"]]


def register_webhook(client: ShopifyGraphQLClient, topic: str, callback_url: str) -> None:
    data = client.execute(
        WEBHOOK_SUBSCRIPTION_CREATE_MUTATION,
        {"topic": topic, "callbackUrl": callback_url},
    )
    result = data["webhookSubscriptionCreate"]
    if result["userErrors"]:
        raise WebhookRegistrationError(str(result["userErrors"]))
    logger.info("Registered webhook: %s -> %s", topic, callback_url)


def register_all(settings: Settings, callback_url: str) -> None:
    """Idempotent: skips any topic already subscribed to this exact callback_url."""
    client = ShopifyGraphQLClient(settings)
    existing = list_existing_subscriptions(client)
    already_registered = {
        sub["topic"]
        for sub in existing
        if (sub.get("endpoint") or {}).get("callbackUrl") == callback_url
    }

    for topic in WEBHOOK_TOPICS:
        if topic in already_registered:
            logger.info("Skipping %s: already registered for %s", topic, callback_url)
            continue
        register_webhook(client, topic, callback_url)


@click.command()
@click.option(
    "--callback-url",
    required=True,
    help="Public HTTPS URL of the webhook receiver (API Gateway invoke URL + route).",
)
def main(callback_url: str) -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    settings = Settings.from_env()
    register_all(settings, callback_url)
    click.echo(f"Webhook registration complete for {callback_url}.")


if __name__ == "__main__":
    main()
