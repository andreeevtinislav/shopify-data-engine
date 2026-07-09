output "webhook_callback_url" {
  description = "Public HTTPS URL Shopify should POST webhooks to. Pass to `register-shopify-webhooks --callback-url` in ../../../ingestion."
  # The $default stage's invoke_url already ends in "/" (no explicit stage
  # name in the path) — trim it before appending the route path, or the
  # result has a double slash that API Gateway's exact route matching rejects.
  value = "${trimsuffix(module.http_api.invoke_urls["shopify-webhook-receiver-api"], "/")}/webhooks/shopify"
}

output "ecr_repository_urls" {
  description = "Push images here (see ../../../ingestion/Dockerfile.webhook and ../../../airflow/Dockerfile) before the first full apply — the Lambda/ECS task resources require their image_tag to already exist."
  value       = module.ecr.repository_urls
}

output "airflow_find_ip_command" {
  description = "The Fargate task's public IP isn't knowable at apply time (assigned to the task's ENI when it starts, not the service). Run this to find it, then browse to http://<ip>:8080."
  value       = "aws ecs list-tasks --cluster ${module.ecs_cluster.cluster_names["shopify-data-engine"]} --service-name shopify-airflow --query 'taskArns[0]' --output text | xargs -I{} aws ecs describe-tasks --cluster ${module.ecs_cluster.cluster_names["shopify-data-engine"]} --tasks {} --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I{} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text"
}
