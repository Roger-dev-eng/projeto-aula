variable "regiao" {
  type = string
}

variable "projeto" {
  type = string
}

variable "ambiente" {
  type = string
}

variable "cidr_vpc" {
  type = string
}

variable "zonas" {
  type = list(string)
}

variable "repositorios" {
  type = list(string)
}

variable "tipo_instancia" {
  type = string
}

variable "quantidade_nos" {
  type = number
}

# Dono/nome do repositório no GitHub (os scripts usam para gravar o segredo do CD)
variable "repositorio_github" {
  type = string
}

# Como o GitHub se identifica para a AWS: "repo:dono@id/nome@id" (os IDs não mudam se o repositório for renomeado)
variable "sub_github" {
  type = string
}
