# HTTP API (not REST API) — cheaper/simpler for proxy-to-Lambda routes.
locals {
  apis = { for a in var.apis : a.name => a }

  routes = merge([
    for a in var.apis : {
      for r in a.routes : "${a.name}.${r.route_key}" => merge(r, { api = a.name })
    }
  ]...)
}

resource "aws_apigatewayv2_api" "this" {
  for_each = local.apis

  name          = each.value.name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = local.routes

  api_id                 = aws_apigatewayv2_api.this[each.value.api].id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.routes

  api_id    = aws_apigatewayv2_api.this[each.value.api].id
  route_key = each.value.route_key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  for_each = local.apis

  api_id      = aws_apigatewayv2_api.this[each.key].id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "this" {
  for_each = local.routes

  statement_id  = "invoke-${each.value.api}-${replace(replace(each.value.route_key, " ", "-"), "/", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this[each.value.api].execution_arn}/*/*"
}
