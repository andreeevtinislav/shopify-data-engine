variable "tables" {
  description = "Tables to create. Each references an existing database and schema by plain name."
  type = list(object({
    database        = string
    schema          = string
    name            = string
    comment         = optional(string)
    change_tracking = optional(bool, false)
    columns = list(object({
      name               = string
      type               = string
      nullable           = optional(bool, true)
      default_expression = optional(string)
    }))
  }))
}
