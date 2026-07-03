output "databases" {
  description = "Map of database name -> snowflake_database resource"
  value       = snowflake_database.this
}

output "schemas" {
  description = "Map of '<database>.<schema>' -> snowflake_schema resource"
  value       = snowflake_schema.this
}

output "schema_names" {
  description = "Map of '<database>.<schema>' -> plain schema name"
  value       = { for k, v in snowflake_schema.this : k => v.name }
}

output "schema_fully_qualified_names" {
  description = "Map of '<database>.<schema>' -> fully qualified schema name, for use in grant on_schema blocks"
  value       = { for k, v in snowflake_schema.this : k => v.fully_qualified_name }
}
