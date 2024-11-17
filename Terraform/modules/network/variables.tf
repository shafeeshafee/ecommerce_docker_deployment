variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = map(string)
}

variable "private_subnet_cidrs" {
  type = map(string)
}

variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string
}

variable "default_vpc_id" {
  description = "ID of the default VPC"
  type        = string
}
