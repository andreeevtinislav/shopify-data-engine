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

locals {
  inline_policies = {
    "shopify-webhook-receiver-exec" = data.aws_iam_policy_document.webhook_receiver_exec.json
  }

  roles = [
    for r in yamldecode(file("${path.module}/iam_roles.yml")).roles :
    merge(r, { inline_policy_json = local.inline_policies[r.name] })
  ]
}

module "iam_role" {
  source = "../../modules/iam_role"

  roles = local.roles

  depends_on = [module.secret, module.log_group]
}
