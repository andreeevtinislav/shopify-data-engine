variable "databases" {
  description = "Databases and their schemas to create. Tables and stages are separate modules."
  type = list(object({
    name    = string
    comment = optional(string)
    schemas = list(object({
      name    = string
      comment = optional(string)
    }))
  }))
}
