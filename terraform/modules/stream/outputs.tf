output "streams" {
  description = "Map of '<database>.<schema>.<name>' -> snowflake_stream_on_table resource."
  value       = snowflake_stream_on_table.this
}
