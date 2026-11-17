output "urls" {
  value = { for nome, repo in aws_ecr_repository.este : nome => repo.repository_url }
}

output "arns" {
  value = { for nome, repo in aws_ecr_repository.este : nome => repo.arn }
}
