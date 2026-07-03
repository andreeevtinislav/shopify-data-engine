variable "role_name" {
  type = string
}

variable "role_comment" {
  type    = string
  default = null
}

variable "service_user_name" {
  type = string
}

variable "service_user_comment" {
  type    = string
  default = null
}

variable "warehouse_name" {
  description = "Warehouse to grant USAGE on and set as the service user's default."
  type        = string
}

variable "database_name" {
  description = "Database to grant USAGE on and use in the service user's default namespace."
  type        = string
}

variable "schema_name" {
  description = "Plain schema name (e.g. RAW), used for the service user's default namespace."
  type        = string
}

variable "schema_fully_qualified_name" {
  description = "Fully qualified schema name (e.g. \"SHOPIFY_DATA\".\"RAW\"), required by grant on_schema/on_schema_object blocks."
  type        = string
}

variable "tables" {
  description = "Table resources this role's grants must be created after (ordering only, not read)."
  type        = any
  default     = {}
}

variable "stages" {
  description = "Stage resources this role's grants must be created after (ordering only, not read)."
  type        = any
  default     = {}
}

variable "pipeline_rsa_public_key" {
  description = "RSA public key for the service user's key-pair auth."
  type        = string
  sensitive   = true
}
