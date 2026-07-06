variable "streams" {
  description = "Streams to create. Each references an existing table by its fully qualified identifier (on_table, e.g. \"SHOPIFY_DATA\".\"RAW\".\"SHOPIFY_ORDERS_JSON\")."
  type = list(object({
    database = string
    schema   = string
    name     = string
    on_table = string
    comment  = optional(string)
  }))
}
