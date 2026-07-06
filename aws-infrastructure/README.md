# aws-infrastructure

Provisions the AWS side of the platform that `../ingestion` runs on in production: an ECR repo per image, the Lambda + API Gateway HTTP API that receives Shopify order webhooks, the ECS Fargate task (+ Datadog Agent sidecar) that runs the polling batch sync, Secrets Manager entries for everything both need, and least-privilege IAM scoped to exactly those resources.

Organized the same way as `../terraform`: reusable modules (`modules/{ecr,secret,iam_role,log_group,lambda,http_api,ecs_task}`) driven by per-environment YAML config (`environments/production/*.yml`). To add a new repo, secret, log group, Lambda, HTTP API, or ECS task, edit the relevant `.yml` file — no HCL changes needed unless the shape of the config itself changes. A few files (`iam_roles.tf`, `lambdas.tf`, `http_apis.tf`, `ecs_tasks.tf`) also compute values that reference other modules' outputs (an IAM policy's resource ARNs, a Lambda's image URI) — those can't live in plain YAML, so they're merged onto the YAML-decoded shape in the matching `.tf` file, following the same pattern `../terraform/environments/production/access.tf` uses for `service_user_rsa_public_keys`.

## Setup

### 1. AWS credentials

Use a dedicated IAM user (not root) scoped to the actions/resources this config touches — see `iam-deployer-policy.json.example` for a starting point. Configure the CLI (`aws configure`) or export `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` before running Terraform.

Note: the example policy covers `module.ecr`, `module.secret`, `module.iam_role`, `module.lambda`, `module.http_api`, and `module.log_group` (the webhook receiver path). `module.ecs_task` wraps a third-party module (`DataDog/ecs-datadog/aws`) whose exact IAM/ECS footprint isn't enumerated here — if you apply that part too, expect to iterate on the deployer policy based on the `AccessDenied` errors Terraform reports (normal for least-privilege setup), rather than pre-granting broad `ecs:*`/`iam:*`.

### 2. Snowflake prerequisites

Run `../terraform` first — this config expects `SHOPIFY_WEBHOOK_ROLE`/`SHOPIFY_WEBHOOK_SVC` to already exist (see `../terraform/README.md` step 2), since the webhook Lambda authenticates to Snowflake as that service user.

### 3. Bootstrap the ECR repos, then apply

`module.ecr` and `module.lambda`/`module.ecs_task` are defined in the same config, which creates a bootstrapping order: each repo must exist and already contain the image tag being deployed before the Lambda/ECS task resources referencing it can be created.

```bash
cd environments/production
terraform init

# Step 1: create just the two ECR repos
terraform apply -target=module.ecr

# Step 2: build & push both images (get repo URLs from the ecr_repository_urls output)
docker build -f ../../../ingestion/Dockerfile.webhook -t <shopify-webhook-receiver repo url>:latest ../../../ingestion
docker push <shopify-webhook-receiver repo url>:latest
# (build/push an image for the shopify-engine repo too, however that's built today)

aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com

# Step 3: full apply now that both images exist
terraform apply \
  -var="shopify_shop_domain=<shop>.myshopify.com" \
  -var="shopify_api_version=2025-10" \
  -var="snowflake_account=<account>" \
  -var="shopify_access_token=<token>" \
  -var="shopify_webhook_secret=<a secret you generate — Shopify signs with it>" \
  -var="snowflake_webhook_private_key_pem=$(cat ../../../ingestion/secrets/webhook_key.p8)" \
  -var="datadog_api_key=<datadog api key>"
```

The `webhook_callback_url` output is what you pass to `register-shopify-webhooks --callback-url` in `../ingestion`.

## Layout

```
aws-infrastructure/
├── modules/                  # reusable, environment-agnostic
│   ├── ecr/                    # aws_ecr_repository
│   ├── secret/                  # Secrets Manager secret + version (values passed separately from shape)
│   ├── iam_role/                  # aws_iam_role + inline/managed policies
│   ├── log_group/                   # aws_cloudwatch_log_group
│   ├── lambda/                        # aws_lambda_function (container image only)
│   ├── http_api/                        # apigatewayv2 api/integration/route/stage/permission
│   └── ecs_task/                          # wraps DataDog/ecs-datadog/aws's ecs_fargate module
└── environments/
    └── production/
        ├── providers.tf, variables.tf, outputs.tf
        ├── ecr.tf         + ecr.yml
        ├── secrets.tf     + secrets.yml
        ├── log_groups.tf  + log_groups.yml
        ├── iam_roles.tf   + iam_roles.yml
        ├── lambdas.tf     + lambdas.yml
        ├── http_apis.tf   + http_apis.yml
        └── ecs_tasks.tf   + ecs_tasks.yml
```
