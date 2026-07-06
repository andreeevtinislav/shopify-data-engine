# Note: inline_policy_json is a plain string (a pre-built policy document),
# not built inside this module — it commonly needs to reference other
# modules' resource ARNs (secrets, log groups), so the caller builds it via
# `data.aws_iam_policy_document` and passes the rendered JSON in. Mirrors
# ../../../terraform/modules/table's "plain strings in, caller owns
# depends_on" convention.
locals {
  roles = { for r in var.roles : r.name => r }

  managed_policy_attachments = merge([
    for k, r in local.roles : {
      for arn in coalesce(r.managed_policy_arns, []) : "${k}.${arn}" => { role = k, arn = arn }
    }
  ]...)
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.roles

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [each.value.assume_role_service]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.roles

  name               = each.value.name
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json
}

resource "aws_iam_role_policy" "inline" {
  for_each = { for k, r in local.roles : k => r if r.inline_policy_json != null }

  name   = "${each.value.name}-inline"
  role   = aws_iam_role.this[each.key].id
  policy = each.value.inline_policy_json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.managed_policy_attachments

  role       = aws_iam_role.this[each.value.role].name
  policy_arn = each.value.arn
}
