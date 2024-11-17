variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = map(string)
}

variable "private_subnet_ids" {
  type = map(string)
}

variable "bastion_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "rds_address" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "dockerhub_username" {
  type = string
}

variable "dockerhub_password" {
  type      = string
  sensitive = true
}

variable "key_name" {
  type = string
}

variable "instance_type_bastion" {
  type = string
}

variable "instance_type_app" {
  type = string
}

variable "nat_gateway_id" {
  type = string
}
