# One access point per filesystem, rooted at root_directory with the given
# posix owner — must match the uid/gid the container actually runs as (e.g.
# the official Airflow image's "airflow" user is uid=50000, gid=0), or the
# container won't be able to write to the mounted directory.
locals {
  filesystems = { for f in var.filesystems : f.name => f }

  mount_targets = merge([
    for fname, f in local.filesystems : {
      for subnet_id in f.subnet_ids : "${fname}.${subnet_id}" => {
        filesystem = fname
        subnet_id  = subnet_id
      }
    }
  ]...)
}

resource "aws_efs_file_system" "this" {
  for_each = local.filesystems

  creation_token = each.value.name
  encrypted      = true

  tags = {
    Name = each.value.name
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = local.mount_targets

  file_system_id  = aws_efs_file_system.this[each.value.filesystem].id
  subnet_id       = each.value.subnet_id
  security_groups = local.filesystems[each.value.filesystem].security_group_ids
}

resource "aws_efs_access_point" "this" {
  for_each = local.filesystems

  file_system_id = aws_efs_file_system.this[each.key].id

  posix_user {
    uid = each.value.posix_uid
    gid = each.value.posix_gid
  }

  root_directory {
    path = each.value.root_directory
    creation_info {
      owner_uid   = each.value.posix_uid
      owner_gid   = each.value.posix_gid
      permissions = "0755"
    }
  }
}
