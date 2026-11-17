module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name            = var.nome
  cidr            = var.cidr
  azs             = var.zonas
  public_subnets  = [for i, z in var.zonas : cidrsubnet(var.cidr, 8, i + 1)]
  private_subnets = [for i, z in var.zonas : cidrsubnet(var.cidr, 8, i + 11)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
