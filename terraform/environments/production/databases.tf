module "database" {
  source = "../../modules/database"

  databases = yamldecode(file("${path.module}/databases.yml")).databases
}
