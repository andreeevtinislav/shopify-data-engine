variable "filesystems" {
  description = "EFS filesystems to create, one access point each. subnet_ids/security_group_ids are plain values (not resource references), consistent with modules/table's convention — the caller is responsible for depends_on."
  type = list(object({
    name               = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
    root_directory     = string
    posix_uid          = number
    posix_gid          = number
  }))
}
