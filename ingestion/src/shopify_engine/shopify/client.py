import time
from typing import Any

import requests

from shopify_engine.config import Settings

MAX_RETRIES = 5
INITIAL_BACKOFF_SECONDS = 2.0
# Fraction of the account's max cost bucket we require to be available before
# firing another request; below this we proactively wait for it to refill.
MIN_AVAILABLE_COST_BUFFER = 50


class ShopifyGraphQLError(RuntimeError):
    pass


class ShopifyGraphQLClient:
    def __init__(self, settings: Settings):
        self._url = settings.shopify_graphql_url
        self._session = requests.Session()
        self._session.headers.update(
            {
                "X-Shopify-Access-Token": settings.shopify_access_token,
                "Content-Type": "application/json",
            }
        )
        self._available_cost: float | None = None
        self._restore_rate: float | None = None

    def execute(self, query: str, variables: dict[str, Any] | None = None) -> dict[str, Any]:
        self._wait_for_cost_budget()

        backoff = INITIAL_BACKOFF_SECONDS
        for attempt in range(1, MAX_RETRIES + 1):
            response = self._session.post(
                self._url, json={"query": query, "variables": variables or {}}, timeout=60
            )

            if response.status_code == 429:
                self._sleep_and_backoff(backoff, attempt)
                backoff *= 2
                continue

            response.raise_for_status()
            payload = response.json()
            self._update_cost_state(payload)

            errors = payload.get("errors")
            if errors:
                if _is_throttled(errors):
                    self._sleep_and_backoff(backoff, attempt)
                    backoff *= 2
                    continue
                raise ShopifyGraphQLError(str(errors))

            return payload["data"]

        raise ShopifyGraphQLError(f"Exceeded {MAX_RETRIES} retries against {self._url}")

    def _wait_for_cost_budget(self) -> None:
        if self._available_cost is None or self._restore_rate is None:
            return
        if self._available_cost >= MIN_AVAILABLE_COST_BUFFER:
            return
        deficit = MIN_AVAILABLE_COST_BUFFER - self._available_cost
        sleep_seconds = deficit / self._restore_rate
        time.sleep(sleep_seconds)
        self._available_cost = MIN_AVAILABLE_COST_BUFFER

    def _update_cost_state(self, payload: dict[str, Any]) -> None:
        throttle_status = (
            payload.get("extensions", {}).get("cost", {}).get("throttleStatus")
        )
        if throttle_status:
            self._available_cost = throttle_status["currentlyAvailable"]
            self._restore_rate = throttle_status["restoreRate"]

    @staticmethod
    def _sleep_and_backoff(seconds: float, attempt: int) -> None:
        if attempt >= MAX_RETRIES:
            return
        time.sleep(seconds)


def _is_throttled(errors: list[dict[str, Any]]) -> bool:
    return any(e.get("extensions", {}).get("code") == "THROTTLED" for e in errors)
