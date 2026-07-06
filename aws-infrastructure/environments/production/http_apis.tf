# Each route in http_apis.yml references a Lambda by lambda_function_key
# (a name into module.lambda's outputs) rather than an ARN directly, since
# the ARN doesn't exist until that module is applied.
locals {
  http_apis = [
    for a in yamldecode(file("${path.module}/http_apis.yml")).apis : {
      name = a.name
      routes = [
        for r in a.routes : {
          route_key            = r.route_key
          lambda_invoke_arn    = module.lambda.invoke_arns[r.lambda_function_key]
          lambda_function_name = module.lambda.function_names[r.lambda_function_key]
        }
      ]
    }
  ]
}

module "http_api" {
  source = "../../modules/http_api"

  apis = local.http_apis

  depends_on = [module.lambda]
}
