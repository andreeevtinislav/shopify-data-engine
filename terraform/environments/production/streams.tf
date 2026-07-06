# on_table is a plain fully-qualified string (not a resource reference), so this
# needs an explicit depends_on — Terraform can't infer the ordering from the
# yaml values alone.
module "stream" {
  source = "../../modules/stream"

  streams = yamldecode(file("${path.module}/streams.yml")).streams

  depends_on = [module.table]
}
