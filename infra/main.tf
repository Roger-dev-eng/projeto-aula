terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.regiao

  default_tags {
    tags = {
      Projeto  = var.projeto
      Ambiente = var.ambiente
    }
  }
}

data "aws_caller_identity" "atual" {}

module "rede" {
  source = "./modules/rede"

  nome  = var.projeto
  cidr  = var.cidr_vpc
  zonas = var.zonas
}

module "ecr" {
  source = "./modules/ecr"

  repositorios = var.repositorios
}

module "eks" {
  source = "./modules/eks"

  nome           = var.projeto
  vpc_id         = module.rede.vpc_id
  subnet_ids     = module.rede.subnets_privadas
  tipo_instancia = var.tipo_instancia
  quantidade_nos = var.quantidade_nos
}

module "site" {
  source = "./modules/site"

  nome_bucket = "${var.projeto}-front-${data.aws_caller_identity.atual.account_id}"
}

module "cicd" {
  source = "./modules/cicd"

  nome                = var.projeto
  sub_github          = var.sub_github
  nome_cluster        = module.eks.nome
  arn_cluster         = module.eks.arn
  arn_repositorio_ecr = module.ecr.arns["back"]
}
