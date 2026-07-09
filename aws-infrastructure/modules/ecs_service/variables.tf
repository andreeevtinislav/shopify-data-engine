variable "services" {
  description = "ECS Fargate services (task definition + always-on service) to create. Cross-references (role ARNs, subnets, security groups, EFS ids) are plain strings, consistent with modules/table's convention — the caller is responsible for depends_on."
  type = list(object({
    name               = string
    cluster_arn        = string
    cpu                = optional(number, 512)
    memory             = optional(number, 1024)
    execution_role_arn = string
    task_role_arn      = string
    container_name     = string
    image_uri          = string
    container_port     = optional(number)
    command            = optional(list(string))
    environment        = optional(map(string), {})
    secrets            = optional(map(string), {}) # container env var name -> Secrets Manager ARN
    log_group_name     = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
    assign_public_ip   = optional(bool, true)
    desired_count      = optional(number, 1)
    efs_mounts = optional(list(object({
      access_point_id = string
      file_system_id  = string
      container_path  = string
    })), [])
  }))
}
