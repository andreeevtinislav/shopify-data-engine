module "stage" {
  source = "../../modules/stage"

  stages = yamldecode(file("${path.module}/stages.yml")).stages

  depends_on = [module.database]
}
