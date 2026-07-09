# subnet_ids/security_group_ids reference the default VPC lookup and the
# Airflow security group (networking.tf), so those extras are merged onto the
# plain YAML shape here rather than living in efs.yml — same pattern as
# iam_roles.tf/lambdas.tf.
locals {
  efs_filesystems = [
    for f in yamldecode(file("${path.module}/efs.yml")).filesystems : merge(f, {
      subnet_ids         = data.aws_subnets.default.ids
      security_group_ids = [aws_security_group.airflow.id]
    })
  ]
}

module "efs" {
  source = "../../modules/efs"

  filesystems = local.efs_filesystems

  depends_on = [aws_security_group.airflow]
}
