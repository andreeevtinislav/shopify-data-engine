output "apis" {
  description = "Map of api name -> aws_apigatewayv2_api resource"
  value       = aws_apigatewayv2_api.this
}

output "invoke_urls" {
  description = "Map of api name -> $default stage invoke_url (append the route path yourself)"
  value       = { for k, v in aws_apigatewayv2_stage.default : k => v.invoke_url }
}
