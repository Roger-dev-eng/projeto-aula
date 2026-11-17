output "nome" {
  value = module.eks.cluster_name
}

output "arn" {
  value = module.eks.cluster_arn
}
