output "role_name" {
  value = snowflake_account_role.this.name
}

output "service_user_name" {
  value = snowflake_service_user.this.name
}
