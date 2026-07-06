output "tasks" {
  description = "Map of '<database>.<schema>.<name>' -> snowflake_task resource."
  value       = snowflake_task.this
}
