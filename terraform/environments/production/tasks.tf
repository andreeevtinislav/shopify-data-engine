# References the stream and the ORDER_CHANGE_LOG table by fully-qualified name
# inside `when`/`sql_statement` (plain strings), so this needs an explicit
# depends_on for correct ordering.
module "task" {
  source = "../../modules/task"

  tasks = yamldecode(file("${path.module}/tasks.yml")).tasks

  depends_on = [module.table, module.stream]
}
