module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name                   = var.nome
  kubernetes_version     = "1.37"
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = { before_compute = true }
  }

  eks_managed_node_groups = {
    padrao = {
      instance_types = [var.tipo_instancia]
      min_size       = var.quantidade_nos
      max_size       = var.quantidade_nos + 1
      desired_size   = var.quantidade_nos
    }
  }
}
