variable "roles" {
  description = "IAM roles to create."
  type = list(object({
    name                = string
    assume_role_service = string # e.g. "lambda.amazonaws.com"
    inline_policy_json  = optional(string)
    managed_policy_arns = optional(list(string), [])
  }))
}
