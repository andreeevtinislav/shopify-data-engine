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
  customer { id }
  lineItems(first: 250) {
    pageInfo { hasNextPage }
    edges {
      node {
        id
        title
        quantity
        sku
        variant { id }
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
