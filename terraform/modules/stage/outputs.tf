output "stages" {
  description = "Map of '<database>.<schema>.<stage>' -> snowflake_stage_internal resource. Pass this into the access module's depends_on so grants wait for stages to exist."
  value       = snowflake_stage_internal.this
}

output "fully_qualified_names" {
  value = { for k, v in snowflake_stage_internal.this : k => v.fully_qualified_name }
}
