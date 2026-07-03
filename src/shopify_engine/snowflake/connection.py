import snowflake.connector

from shopify_engine.config import Settings


def get_connection(settings: Settings) -> snowflake.connector.SnowflakeConnection:
    kwargs: dict = {
        "account": settings.snowflake_account,
        "user": settings.snowflake_user,
        "warehouse": settings.snowflake_warehouse,
        "database": settings.snowflake_database,
        "schema": settings.snowflake_schema,
        "role": settings.snowflake_role,
    }

    if settings.snowflake_private_key_path:
        kwargs["private_key_file"] = settings.snowflake_private_key_path
    else:
        kwargs["password"] = settings.snowflake_password

    return snowflake.connector.connect(**kwargs)
