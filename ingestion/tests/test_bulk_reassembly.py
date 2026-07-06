from shopify_engine.shopify.bulk import reassemble_orders, reassemble_products


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


def test_reassemble_products_groups_variants_under_parent():
    lines = [
        {"id": "gid://shopify/Product/1", "title": "Widget"},
        {
            "id": "gid://shopify/ProductVariant/10",
            "sku": "WID-S",
            "__parentId": "gid://shopify/Product/1",
        },
        {
            "id": "gid://shopify/ProductVariant/11",
            "sku": "WID-L",
            "__parentId": "gid://shopify/Product/1",
        },
        {"id": "gid://shopify/Product/2", "title": "Gadget"},
    ]

    products = reassemble_products(lines)

    assert [p["id"] for p in products] == ["gid://shopify/Product/1", "gid://shopify/Product/2"]

    product_1 = products[0]
    assert len(product_1["variants"]) == 2
    assert product_1["variants"][0]["sku"] == "WID-S"
    assert "__parentId" not in product_1["variants"][0]

    product_2 = products[1]
    assert product_2["variants"] == []


def test_reassemble_products_skips_orphaned_child_lines():
    lines = [
        {
            "id": "gid://shopify/ProductVariant/99",
            "sku": "ORPHAN",
            "__parentId": "gid://shopify/Product/999",
        },
        {"id": "gid://shopify/Product/1", "title": "Widget"},
    ]

    products = reassemble_products(lines)

    assert len(products) == 1
    assert products[0]["variants"] == []
