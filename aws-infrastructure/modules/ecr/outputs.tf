output "repositories" {
  description = "Map of repo name -> aws_ecr_repository resource"
  value       = aws_ecr_repository.this
}

output "repository_urls" {
  description = "Map of repo name -> repository_url"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
