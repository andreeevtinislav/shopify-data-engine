# Note: secret values are passed separately (var.secret_values, keyed by name),
# not part of var.secrets — mirrors ../../../terraform/modules/access's
# service_user_rsa_public_keys convention of keeping sensitive values out of
# the plain-YAML shape config.
locals {
  secrets = { for s in var.secrets : s.name => s }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name        = each.value.name
  description = try(each.value.description, null)
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = local.secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = var.secret_values[each.key]
}
