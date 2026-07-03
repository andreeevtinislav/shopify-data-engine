module "warehouse" {
  source = "../../modules/warehouse"

  warehouses = yamldecode(file("${path.module}/warehouses.yml")).warehouses
}
