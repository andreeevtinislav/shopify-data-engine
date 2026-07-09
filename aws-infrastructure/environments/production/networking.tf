# Uses the account's default VPC/subnets rather than a dedicated VPC — no new
# networking to build for a single Fargate task. Not modularized (like
# providers.tf) since there's exactly one of these, not a growing list of
# similarly-shaped objects.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "airflow" {
  name        = "shopify-airflow"
  description = "Airflow webserver (8080) and EFS (2049) access for the shopify-airflow ECS service"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Airflow webserver UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.airflow_ui_allowed_cidr]
  }

  # EFS mount target traffic, restricted to this same security group — only
  # the Airflow task itself can reach the filesystem, not the whole VPC.
  ingress {
    description = "EFS (NFS) from this security group"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
