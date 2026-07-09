variable "clusters" {
  description = "ECS clusters to create."
  type = list(object({
    name               = string
    container_insights = optional(bool, false)
  }))
}
