# database/schema are passed as plain strings, so this needs an explicit
# depends_on — Terraform can't infer the ordering from the yaml values alone.
module "table" {
  source = "../../modules/table"

  tables = yamldecode(file("${path.module}/tables.yml")).tables

  depends_on = [module.database]
}
