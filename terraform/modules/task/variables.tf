variable "tasks" {
  description = "Tasks to create. Each is a warehouse-scheduled or triggered Snowflake task."
  type = list(object({
    database         = string
    schema           = string
    name             = string
    warehouse        = optional(string)
    comment          = optional(string)
    when             = optional(string)
    schedule_minutes = optional(number)
    sql_statement    = string
    started          = bool
  }))
}
