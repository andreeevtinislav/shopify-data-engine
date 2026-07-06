ORDER_FIELDS = """
  id
  name
  createdAt
  updatedAt
  cancelledAt
  closedAt
  displayFinancialStatus
  displayFulfillmentStatus
  currentTotalPriceSet { shopMoney { amount currencyCode } }
  subtotalPriceSet { shopMoney { amount } }
  totalDiscountsSet { shopMoney { amount } }
  totalTaxSet { shopMoney { amount } }
  lineItems(first: 250) {
    pageInfo { hasNextPage }
    edges {
      node {
        id
        title
        quantity
        sku
        originalUnitPriceSet { shopMoney { amount } }
        totalDiscountSet { shopMoney { amount } }
      }
    }
  }
  refunds {
    id
    createdAt
    totalRefundedSet { shopMoney { amount } }
  }
"""

# Cursor-paginated query for incremental syncs.
ORDERS_INCREMENTAL_QUERY = f"""
query OrdersIncremental($cursor: String, $queryFilter: String!) {{
  orders(first: 50, after: $cursor, sortKey: UPDATED_AT, query: $queryFilter) {{
    pageInfo {{ hasNextPage endCursor }}
    edges {{
      node {{
        {ORDER_FIELDS}
      }}
    }}
  }}
}}
"""

# Query text handed to bulkOperationRunQuery for the full historical backfill.
# No `first`/pagination arguments here — Shopify paginates bulk queries internally
# and streams every order to the resulting JSONL file.
ORDERS_BULK_QUERY = f"""
{{
  orders {{
    edges {{
      node {{
        {ORDER_FIELDS}
      }}
    }}
  }}
}}
"""

PRODUCT_FIELDS = """
  id
  title
  handle
  vendor
  productType
  status
  createdAt
  updatedAt
  tags
  variants(first: 100) {
    pageInfo { hasNextPage }
    edges {
      node {
        id
        title
        sku
        price
        compareAtPrice
        inventoryQuantity
        position
      }
    }
  }
"""

# Cursor-paginated query for incremental syncs.
PRODUCTS_INCREMENTAL_QUERY = f"""
query ProductsIncremental($cursor: String, $queryFilter: String!) {{
  products(first: 50, after: $cursor, sortKey: UPDATED_AT, query: $queryFilter) {{
    pageInfo {{ hasNextPage endCursor }}
    edges {{
      node {{
        {PRODUCT_FIELDS}
      }}
    }}
  }}
}}
"""

# Query text handed to bulkOperationRunQuery for the full historical backfill.
PRODUCTS_BULK_QUERY = f"""
{{
  products {{
    edges {{
      node {{
        {PRODUCT_FIELDS}
      }}
    }}
  }}
}}
"""

START_BULK_OPERATION_MUTATION = """
mutation StartBulkOperation($query: String!) {
  bulkOperationRunQuery(query: $query) {
    bulkOperation { id status }
    userErrors { field message }
  }
}
"""

CURRENT_BULK_OPERATION_QUERY = """
query CurrentBulkOperation {
  currentBulkOperation {
    id
    status
    errorCode
    objectCount
    url
  }
}
"""

# Single-order lookup, shaped identically to ORDERS_INCREMENTAL_QUERY/ORDERS_BULK_QUERY
# (same ORDER_FIELDS) so a refetched order can go through the exact same loader
# path as the polling/backfill paths, regardless of which one triggered the fetch.
ORDER_BY_ID_QUERY = f"""
query OrderById($id: ID!) {{
  order(id: $id) {{
    {ORDER_FIELDS}
  }}
}}
"""

WEBHOOK_SUBSCRIPTIONS_QUERY = """
query WebhookSubscriptions($topics: [WebhookSubscriptionTopic!]) {
  webhookSubscriptions(first: 50, topics: $topics) {
    edges {
      node {
        id
        topic
        endpoint {
          ... on WebhookHttpEndpoint {
            callbackUrl
          }
        }
      }
    }
  }
}
"""

# Note: WebhookSubscriptionInput has no field for shaping the delivered
# payload with a custom GraphQL selection (confirmed against the live Admin
# API — an earlier version of this mutation tried passing `query` and Shopify
# rejected it with "InputObject 'WebhookSubscriptionInput' doesn't accept
# argument 'query'"). Every topic delivers Shopify's default JSON payload
# shape, so the webhook handler always re-fetches the full order via
# ORDER_BY_ID_QUERY rather than trusting the delivered body's shape.
WEBHOOK_SUBSCRIPTION_CREATE_MUTATION = """
mutation WebhookSubscriptionCreate($topic: WebhookSubscriptionTopic!, $callbackUrl: URL!) {
  webhookSubscriptionCreate(
    topic: $topic
    webhookSubscription: { callbackUrl: $callbackUrl, format: JSON }
  ) {
    webhookSubscription { id }
    userErrors { field message }
  }
}
"""
