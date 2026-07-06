variable "tasks" {
  description = "ECS Fargate task definitions with a Datadog Agent sidecar. image_uri/dd_api_key_secret_arn are plain strings (not resource references), consistent with modules/table's convention — the caller is responsible for depends_on."
  type = list(object({
    family                = string
    container_name        = string
    image_uri             = string
    command               = list(string)
    cpu                   = optional(number, 512)
    memory                = optional(number, 1024)
    dd_api_key_secret_arn = string
    dd_site               = optional(string, "datadoghq.eu")
    dd_service            = string
    dd_env                = optional(string, "production")
    dd_version            = optional(string, "latest")
    environment           = optional(map(string), {})
  }))
}
