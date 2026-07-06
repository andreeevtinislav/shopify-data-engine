module "log_group" {
  source = "../../modules/log_group"

  log_groups = yamldecode(file("${path.module}/log_groups.yml")).log_groups
}
