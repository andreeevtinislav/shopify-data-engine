variable "warehouses" {
  description = "Warehouses to create."
  type = list(object({
    name                = string
    size                = string
    auto_suspend        = number
    auto_resume         = bool
    initially_suspended = bool
    comment             = optional(string)
  }))
}
