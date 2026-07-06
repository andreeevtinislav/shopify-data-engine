locals {
  repositories = { for r in var.repositories : r.name => r }
}

resource "aws_ecr_repository" "this" {
  for_each = local.repositories

  name                 = each.value.name
  image_tag_mutability = each.value.tag_mutability

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }
}
