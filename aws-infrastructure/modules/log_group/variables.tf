variable "log_groups" {
  description = "CloudWatch log groups to create."
  type = list(object({
    name              = string
    retention_in_days = optional(number, 30)
  }))
}
