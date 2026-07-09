module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  clusters = yamldecode(file("${path.module}/ecs_clusters.yml")).clusters
}
