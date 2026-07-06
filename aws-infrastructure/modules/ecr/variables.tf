variable "repositories" {
  description = "ECR repositories to create."
  type = list(object({
    name           = string
    scan_on_push   = optional(bool, true)
    tag_mutability = optional(string, "MUTABLE")
  }))
}
