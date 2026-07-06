variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "dd_api_key" {
  description = "Datadog API key (pass as TF_VAR_dd_api_key at apply time)"
  type        = string
  sensitive   = true
}

variable "dd_site" {
  description = "Datadog intake site"
  type        = string
  default     = "datadoghq.eu"
}

variable "dd_service" {
  description = "Datadog service name"
  type        = string
  default     = "shopify-engine"
}

variable "dd_env" {
  description = "Datadog environment tag"
  type        = string
  default     = "production"
}

variable "dd_version" {
  description = "Application version tag"
  type        = string
  default     = "latest"
}

variable "task_family" {
  description = "ECS task definition family name"
  type        = string
  default     = "shopify-engine"
}

variable "ecr_image_uri" {
  description = "ECR image URI for the shopify-engine container (e.g. 123456789.dkr.ecr.eu-west-1.amazonaws.com/shopify-engine:latest)"
  type        = string
}
