resource "aws_ecr_repository" "este" {
  for_each = toset(var.repositorios)

  name         = each.value
  force_delete = true
}
