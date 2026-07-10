# Cross-module wiring (role ARNs, image URI, EFS ids, networking) is merged
# onto the plain YAML shape here, same pattern as iam_roles.tf/lambdas.tf.
locals {
  airflow_environment = {
    SHOPIFY_SHOP_DOMAIN    = var.shopify_shop_domain
    SHOPIFY_API_VERSION    = var.shopify_api_version
    SNOWFLAKE_ACCOUNT      = var.snowflake_account
    SNOWFLAKE_WAREHOUSE    = var.snowflake_warehouse
    SNOWFLAKE_DATABASE     = var.snowflake_database
    AIRFLOW_ADMIN_USERNAME = "admin"
  }

  # Resolved by the ECS agent (via the execution role) straight into
  # container env vars at task start — the entrypoint then writes the two PEM
  # values out to files, and uses AIRFLOW_ADMIN_PASSWORD to create a fixed
  # admin login before airflow standalone can generate its own random one
  # (see ../../../airflow/entrypoint.sh).
  airflow_secrets = {
    SHOPIFY_ACCESS_TOKEN               = module.secret.secret_arns["shopify/access-token"]
    SNOWFLAKE_PIPELINE_PRIVATE_KEY_PEM = module.secret.secret_arns["snowflake/pipeline-private-key"]
    SNOWFLAKE_DBT_PRIVATE_KEY_PEM      = module.secret.secret_arns["snowflake/dbt-private-key"]
    AIRFLOW_ADMIN_PASSWORD             = module.secret.secret_arns["airflow/admin-password"]
  }

  service_extras = {
    "shopify-airflow" = {
      cluster_arn        = module.ecs_cluster.cluster_arns["shopify-data-engine"]
      execution_role_arn = module.iam_role.role_arns["shopify-airflow-exec"]
      task_role_arn      = module.iam_role.role_arns["shopify-airflow-task"]
      image_uri          = "${module.ecr.repository_urls["shopify-airflow"]}:${var.image_tag}"
      environment        = local.airflow_environment
      secrets            = local.airflow_secrets
      log_group_name     = "/ecs/shopify-airflow"
      subnet_ids         = data.aws_subnets.default.ids
      security_group_ids = [aws_security_group.airflow.id]
      # NOT the SQLite metadata DB (/opt/airflow/data) — SQLite's file locking
      # doesn't work reliably over NFS/EFS, which caused the scheduler to
      # crash with "database is locked". The DB stays on the task's own
      # local/ephemeral storage; only plain-text task logs go on EFS, which
      # has no such locking requirement.
      efs_mounts = [
        {
          access_point_id = module.efs.access_point_ids["shopify-airflow-data"]
          file_system_id  = module.efs.file_system_ids["shopify-airflow-data"]
          container_path  = "/opt/airflow/logs"
        }
      ]
    }
  }

  services = [
    for s in yamldecode(file("${path.module}/ecs_services.yml")).services :
    merge(s, local.service_extras[s.name])
  ]
}

module "ecs_service" {
  source = "../../modules/ecs_service"

  services = local.services

  depends_on = [
    module.ecs_cluster, module.iam_role, module.ecr, module.secret,
    module.log_group, module.efs, aws_security_group.airflow,
  ]
}
