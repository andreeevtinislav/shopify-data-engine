variable "roles" {
  description = "Account roles, their service users, and schema-level grants to provision."
  type = list(object({
    name    = string
    comment = optional(string)
    service_user = object({
      name             = string
      comment          = optional(string)
      default_database = string
      default_schema   = string
    })
    grants = list(object({
      database     = string
      schema       = string
      privilege    = string       # "read" | "readwrite"
      object_types = list(string) # subset of ["TABLES", "VIEWS", "STAGES"]
    }))
  }))
}

variable "warehouse_name" {
  description = "Warehouse to grant USAGE on and set as each service user's default."
  type        = string
}

variable "schema_names" {
  description = "Map '<database>.<schema>' -> plain schema name, from module.database, used to build each service user's default namespace."
  type        = map(string)
}

variable "schema_fully_qualified_names" {
  description = "Map '<database>.<schema>' -> fully qualified schema name, from module.database, required by grant on_schema/on_schema_object blocks."
  type        = map(string)
}

variable "tables" {
  description = "Table resources these roles' grants must be created after (ordering only, not read)."
  type        = any
  default     = {}
}

variable "stages" {
  description = "Stage resources these roles' grants must be created after (ordering only, not read)."
  type        = any
  default     = {}
}

variable "service_user_rsa_public_keys" {
  description = "Map of role name -> RSA public key (stripped, single line) for that role's service user."
  type        = map(string)
  sensitive   = true
}
