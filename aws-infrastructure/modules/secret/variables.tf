variable "secrets" {
  description = "Secrets Manager secrets to create (name/description only — values passed separately via secret_values)."
  type = list(object({
    name        = string
    description = optional(string)
  }))
}

variable "secret_values" {
  description = "Map of secret name -> secret value. Must have an entry for every name in var.secrets."
  type        = map(string)
  sensitive   = true
}
