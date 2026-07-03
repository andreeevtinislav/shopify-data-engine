output "role_names" {
  description = "Map of role name -> provisioned role name"
  value       = { for k, v in snowflake_account_role.this : k => v.name }
}

output "service_user_names" {
  description = "Map of role name -> that role's service user name"
  value       = { for k, v in snowflake_service_user.this : k => v.name }
}
