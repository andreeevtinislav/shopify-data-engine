import logging

import click

from shopify_engine.config import Settings
from shopify_engine.sync.orchestrator import run_backfill, run_incremental

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@click.command()
@click.option(
    "--mode",
    type=click.Choice(["backfill", "incremental"]),
    required=True,
    help="backfill: full historical pull via Bulk Operations. incremental: pull orders updated since the last watermark.",
)
@click.option(
    "--limit",
    type=int,
    default=None,
    help="Cap the number of orders fetched (uses direct pagination instead of Bulk Operations for backfill). Useful for a small manual test run.",
)
def main(mode: str, limit: int | None) -> None:
    settings = Settings.from_env()

    if mode == "backfill":
        rows = run_backfill(settings, limit=limit)
    else:
        rows = run_incremental(settings, limit=limit)

    click.echo(f"Synced {rows} order rows ({mode}).")


if __name__ == "__main__":
    main()
