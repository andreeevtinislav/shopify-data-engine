output "tables" {
  description = "Map of '<database>.<schema>.<table>' -> snowflake_table resource. Pass this into the access module's depends_on so grants wait for tables to exist."
  value       = snowflake_table.this
}
