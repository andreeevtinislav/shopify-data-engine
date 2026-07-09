# Inline policy documents are built here (not in iam_roles.yml) because they
# reference other modules' resource ARNs (secrets, log groups) — a plain YAML
# shape can't express that. Mirrors terraform/modules/access's convention of
# taking cross-module maps (e.g. schema_fully_qualified_names) as inputs
# rather than computing them inside the module.
data "aws_iam_policy_document" "webhook_receiver_exec" {
  statement {
    sid     = "ReadWebhookSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      module.secret.secret_arns["shopify/access-token"],
      module.secret.secret_arns["shopify/webhook-secret"],
      module.secret.secret_arns["snowflake/webhook-private-key"],
    ]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${module.log_group.log_group_arns["/aws/lambda/shopify-webhook-receiver"]}:*"]
  }
}

# Execution role: what ECS Agent itself needs to start the task — pull the
# image and resolve the container definition's `secrets` entries into env
# vars. Distinct from the task role below, which is what the *running
# container's own code* is allowed to do.
data "aws_iam_policy_document" "airflow_exec" {
  statement {
    sid     = "ReadAirflowSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      module.secret.secret_arns["shopify/access-token"],
      module.secret.secret_arns["snowflake/pipeline-private-key"],
      module.secret.secret_arns["snowflake/dbt-private-key"],
    ]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${module.log_group.log_group_arns["/ecs/shopify-airflow"]}:*"]
  }

  statement {
    sid       = "PullImage"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = [module.ecr.repositories["shopify-airflow"].arn]
  }

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

# Task role: what the running Airflow container is allowed to do — here just
# mount/write to its own EFS access point, nothing else (it doesn't call any
# other AWS API itself; Snowflake/Shopify creds arrive as plain env vars via
# the execution role's secrets resolution).
data "aws_iam_policy_document" "airflow_task" {
  statement {
    sid       = "MountEfs"
    actions   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
    resources = [module.efs.file_system_arns["shopify-airflow-data"]]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [module.efs.access_point_arns["shopify-airflow-data"]]
    }
  }
}

locals {
  inline_policies = {
    "shopify-webhook-receiver-exec" = data.aws_iam_policy_document.webhook_receiver_exec.json
    "shopify-airflow-exec"          = data.aws_iam_policy_document.airflow_exec.json
    "shopify-airflow-task"          = data.aws_iam_policy_document.airflow_task.json
  }

  roles = [
    for r in yamldecode(file("${path.module}/iam_roles.yml")).roles :
    merge(r, { inline_policy_json = local.inline_policies[r.name] })
  ]
}

module "iam_role" {
  source = "../../modules/iam_role"

  roles = local.roles

  depends_on = [module.secret, module.log_group, module.ecr, module.efs]
}
