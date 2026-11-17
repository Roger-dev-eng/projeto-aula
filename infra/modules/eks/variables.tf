variable "nome" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "tipo_instancia" {
  type = string
}

variable "quantidade_nos" {
  type = number
}
