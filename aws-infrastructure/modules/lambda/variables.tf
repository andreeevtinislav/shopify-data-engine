variable "functions" {
  description = "Lambda functions (container image) to create. role_arn/image_uri are plain strings (not resource references), consistent with modules/table's convention — the caller is responsible for depends_on."
  type = list(object({
    name        = string
    role_arn    = string
    image_uri   = string
    timeout     = optional(number, 30)
    memory_size = optional(number, 512)
    environment = optional(map(string), {})
  }))
}
