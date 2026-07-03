import gzip
import json
from pathlib import Path
from unittest.mock import MagicMock

from shopify_engine.snowflake import loader


def test_write_jsonl_gz_writes_one_order_per_line(tmp_path: Path):
    orders = [{"id": "gid://shopify/Order/1"}, {"id": "gid://shopify/Order/2"}]

    path = loader.write_jsonl_gz(orders, tmp_path)

    with gzip.open(path, "rt", encoding="utf-8") as f:
        lines = [json.loads(line) for line in f]

    assert lines == orders


def test_load_orders_skips_snowflake_roundtrip_when_no_orders(tmp_path: Path):
    conn = MagicMock()

    rows = loader.load_orders(conn, [], tmp_path)

    assert rows == 0
    conn.cursor.assert_not_called()


def test_load_orders_stages_merges_and_cleans_up(tmp_path: Path):
    conn = MagicMock()
    cursor = conn.cursor.return_value
    cursor.fetchone.return_value = (1, 0)  # 1 inserted, 0 updated

    orders = [{"id": "gid://shopify/Order/1", "updatedAt": "2026-01-01T00:00:00Z"}]
    rows = loader.load_orders(conn, orders, tmp_path)

    assert rows == 1

    executed_sql = [call.args[0] for call in cursor.execute.call_args_list]
    assert any("PUT file://" in sql and "AUTO_COMPRESS=FALSE" in sql for sql in executed_sql)
    assert any("MERGE INTO" in sql for sql in executed_sql)
    assert any("REMOVE @" in sql for sql in executed_sql)

    # Local temp file should be cleaned up after load.
    assert list(tmp_path.glob("*.jsonl.gz")) == []
