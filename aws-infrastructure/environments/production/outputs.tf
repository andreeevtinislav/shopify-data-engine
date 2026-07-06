output "webhook_callback_url" {
  description = "Public HTTPS URL Shopify should POST webhooks to. Pass to `register-shopify-webhooks --callback-url` in ../../../ingestion."
  # The $default stage's invoke_url already ends in "/" (no explicit stage
  # name in the path) — trim it before appending the route path, or the
  # result has a double slash that API Gateway's exact route matching rejects.
  value = "${trimsuffix(module.http_api.invoke_urls["shopify-webhook-receiver-api"], "/")}/webhooks/shopify"
}

output "ecr_repository_urls" {
  description = "Push images here (see ../../../ingestion/Dockerfile.webhook) before the first full apply — the Lambda/ECS task resources require their image_tag to already exist."
  value       = module.ecr.repository_urls
}
