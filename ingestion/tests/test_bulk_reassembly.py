from shopify_engine.shopify.bulk import reassemble_orders


def test_reassemble_orders_groups_line_items_under_parent():
    lines = [
        {"id": "gid://shopify/Order/1", "name": "#1001", "refunds": []},
        {
            "id": "gid://shopify/LineItem/10",
            "title": "Widget",
            "quantity": 2,
            "__parentId": "gid://shopify/Order/1",
        },
        {
            "id": "gid://shopify/LineItem/11",
            "title": "Gadget",
            "quantity": 1,
            "__parentId": "gid://shopify/Order/1",
        },
        {"id": "gid://shopify/Order/2", "name": "#1002", "refunds": []},
    ]

    orders = reassemble_orders(lines)

    assert [o["id"] for o in orders] == ["gid://shopify/Order/1", "gid://shopify/Order/2"]

    order_1 = orders[0]
    assert len(order_1["lineItems"]) == 2
    assert order_1["lineItems"][0]["title"] == "Widget"
    assert "__parentId" not in order_1["lineItems"][0]

    order_2 = orders[1]
    assert order_2["lineItems"] == []


def test_reassemble_orders_skips_orphaned_child_lines():
    lines = [
        {"id": "gid://shopify/LineItem/99", "title": "Orphan", "__parentId": "gid://shopify/Order/999"},
        {"id": "gid://shopify/Order/1", "name": "#1001"},
    ]

    orders = reassemble_orders(lines)

    assert len(orders) == 1
    assert orders[0]["lineItems"] == []


def test_reassemble_orders_preserves_non_connection_fields():
    lines = [
        {
            "id": "gid://shopify/Order/1",
            "name": "#1001",
            "refunds": [{"id": "gid://shopify/Refund/1", "totalRefundedSet": {"shopMoney": {"amount": "5.00"}}}],
        },
    ]

    orders = reassemble_orders(lines)

    assert orders[0]["refunds"][0]["id"] == "gid://shopify/Refund/1"
