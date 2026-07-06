# Container image only (not zip) — deliberately doesn't support package_type
# = "Zip". This project's Lambdas depend on snowflake-connector-python, whose
# transitive deps (pyarrow etc.) commonly exceed the 250MB unzipped zip/layer
# limit; container images support up to 10GB.
locals {
  functions = { for f in var.functions : f.name => f }
}

resource "aws_lambda_function" "this" {
  for_each = local.functions

  function_name = each.value.name
  role          = each.value.role_arn
  package_type  = "Image"
  image_uri     = each.value.image_uri
  timeout       = each.value.timeout
  memory_size   = each.value.memory_size

  environment {
    variables = each.value.environment
  }
}
