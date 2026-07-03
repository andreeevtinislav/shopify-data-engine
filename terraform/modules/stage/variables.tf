variable "stages" {
  description = "Internal stages to create. Each references an existing database and schema by plain name."
  type = list(object({
    database         = string
    schema           = string
    name             = string
    comment          = optional(string)
    file_format_type = optional(string) # currently only "JSON" is implemented
  }))
}
