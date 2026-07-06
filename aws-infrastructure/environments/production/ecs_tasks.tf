locals {
  ecs_tasks = [
    for t in yamldecode(file("${path.module}/ecs_tasks.yml")).tasks : merge(t, {
      image_uri             = "${module.ecr.repository_urls["shopify-engine"]}:${var.image_tag}"
      dd_api_key_secret_arn = module.secret.secret_arns["datadog/api-key"]
      environment = {
        DD_SERVICE = t.dd_service
        DD_ENV     = t.dd_env
        DD_VERSION = t.dd_version
      }
    })
  ]
}

module "ecs_task" {
  source = "../../modules/ecs_task"

  tasks = local.ecs_tasks

  depends_on = [module.ecr, module.secret]
}
