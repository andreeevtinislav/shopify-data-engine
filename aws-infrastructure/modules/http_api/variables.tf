variable "apis" {
  description = "API Gateway HTTP APIs to create. lambda_invoke_arn/lambda_function_name are plain strings (not resource references), consistent with modules/table's convention — the caller is responsible for depends_on."
  type = list(object({
    name = string
    routes = list(object({
      route_key            = string # e.g. "POST /webhooks/shopify"
      lambda_invoke_arn    = string
      lambda_function_name = string
    }))
  }))
}
