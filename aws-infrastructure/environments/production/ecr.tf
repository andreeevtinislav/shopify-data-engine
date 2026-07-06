module "ecr" {
  source = "../../modules/ecr"

  repositories = yamldecode(file("${path.module}/ecr.yml")).repositories
}
