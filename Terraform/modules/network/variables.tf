# modules/network/variables.tf

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name tag for VPC"
  type        = string
  default     = "ecommerce-vpc"
}

variable "igw_name" {
  description = "Name tag for Internet Gateway"
  type        = string
  default     = "ecommerce-igw"
}

variable "nat_name" {
  description = "Name tag for NAT Gateway"
  type        = string
  default     = "ecommerce-nat"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "public_subnet_azs" {
  description = "List of availability zones for public subnets"
  type        = list(string)
}

variable "public_subnet_name" {
  description = "Name prefix for public subnets"
  type        = string
  default     = "ecommerce-public"
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "private_subnet_azs" {
  description = "List of availability zones for private subnets"
  type        = list(string)
}

variable "private_subnet_name" {
  description = "Name prefix for private subnets"
  type        = string
  default     = "ecommerce-private"
}

variable "public_rt_name" {
  description = "Name tag for public route table"
  type        = string
  default     = "ecommerce-public-rt"
}

variable "private_rt_name" {
  description = "Name tag for private route table"
  type        = string
  default     = "ecommerce-private-rt"
}
