from datetime import datetime

import snowflake.connector

TABLE = "_SYNC_STATE"


def get_watermark(conn: snowflake.connector.SnowflakeConnection, object_name: str) -> datetime | None:
    cursor = conn.cursor()
    try:
        cursor.execute(
            f"SELECT last_watermark FROM {TABLE} WHERE object_name = %s", (object_name,)
        )
        row = cursor.fetchone()
        return row[0] if row else None
    finally:
        cursor.close()


def start_run(conn: snowflake.connector.SnowflakeConnection, object_name: str) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(
            f"""
            MERGE INTO {TABLE} AS tgt
            USING (SELECT %s AS object_name) AS src
            ON tgt.object_name = src.object_name
            WHEN MATCHED THEN UPDATE SET
              last_run_started_at = CURRENT_TIMESTAMP(), last_run_status = 'RUNNING'
            WHEN NOT MATCHED THEN INSERT (object_name, last_run_started_at, last_run_status)
              VALUES (src.object_name, CURRENT_TIMESTAMP(), 'RUNNING')
            """,
            (object_name,),
        )
    finally:
        cursor.close()


def complete_run(
    conn: snowflake.connector.SnowflakeConnection,
    object_name: str,
    new_watermark: datetime | None,
    records_processed: int,
) -> None:
    cursor = conn.cursor()
    try:
        if new_watermark is not None:
            cursor.execute(
                f"""
                UPDATE {TABLE}
                SET last_watermark = %s, last_run_completed_at = CURRENT_TIMESTAMP(),
                    last_run_status = 'SUCCESS', records_processed = %s
                WHERE object_name = %s
                """,
                (new_watermark, records_processed, object_name),
            )
        else:
            # No records returned this run — don't drift the watermark forward.
            cursor.execute(
                f"""
                UPDATE {TABLE}
                SET last_run_completed_at = CURRENT_TIMESTAMP(),
                    last_run_status = 'SUCCESS', records_processed = %s
                WHERE object_name = %s
                """,
                (records_processed, object_name),
            )
    finally:
        cursor.close()


def fail_run(conn: snowflake.connector.SnowflakeConnection, object_name: str) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(
            f"""
            UPDATE {TABLE}
            SET last_run_completed_at = CURRENT_TIMESTAMP(), last_run_status = 'FAILED'
            WHERE object_name = %s
            """,
            (object_name,),
        )
    finally:
        cursor.close()
