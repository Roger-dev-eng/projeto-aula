output "nome_cluster" {
  value = module.eks.nome
}

output "repositorios" {
  value = module.ecr.urls
}

output "bucket_site" {
  value = module.site.bucket
}

output "url_site" {
  value = module.site.url
}

output "papel_cicd" {
  value = module.cicd.arn_papel
}
