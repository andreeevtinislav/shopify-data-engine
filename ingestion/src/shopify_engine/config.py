import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _require(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


@dataclass(frozen=True)
class Settings:
    shopify_shop_domain: str
    shopify_access_token: str
    shopify_api_version: str

    snowflake_account: str
    snowflake_user: str
    snowflake_password: str | None
    snowflake_private_key_path: str | None
    snowflake_warehouse: str
    snowflake_database: str
    snowflake_schema: str
    snowflake_role: str

    @property
    def shopify_graphql_url(self) -> str:
        return f"https://{self.shopify_shop_domain}/admin/api/{self.shopify_api_version}/graphql.json"

    @classmethod
    def from_env(cls) -> "Settings":
        password = os.environ.get("SNOWFLAKE_PASSWORD") or None
        private_key_path = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH") or None
        if not password and not private_key_path:
            raise RuntimeError(
                "Set either SNOWFLAKE_PASSWORD or SNOWFLAKE_PRIVATE_KEY_PATH"
            )

        return cls(
            shopify_shop_domain=_require("SHOPIFY_SHOP_DOMAIN"),
            shopify_access_token=_require("SHOPIFY_ACCESS_TOKEN"),
            shopify_api_version=_require("SHOPIFY_API_VERSION"),
            snowflake_account=_require("SNOWFLAKE_ACCOUNT"),
            snowflake_user=_require("SNOWFLAKE_USER"),
            snowflake_password=password,
            snowflake_private_key_path=private_key_path,
            snowflake_warehouse=_require("SNOWFLAKE_WAREHOUSE"),
            snowflake_database=_require("SNOWFLAKE_DATABASE"),
            snowflake_schema=_require("SNOWFLAKE_SCHEMA"),
            snowflake_role=_require("SNOWFLAKE_ROLE"),
        )
