variable "dockerhub_username" {
  description = "DockerHub username for pulling container images"
  type        = string
}

variable "dockerhub_password" {
  description = "DockerHub password for pulling container images"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
  default     = "ecommerce_admin"
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string
}

# Optional: Add more variables as needed for customization
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type_app" {
  description = "Instance type for application servers"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_bastion" {
  description = "Instance type for bastion hosts"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = map(string)
  default = {
    "us-east-1a" = "10.0.1.0/24"
    "us-east-1b" = "10.0.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = map(string)
  default = {
    "us-east-1a" = "10.0.3.0/24"
    "us-east-1b" = "10.0.4.0/24"
  }
}

variable "db_instance_class" {
  description = "Instance class for RDS database"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS database in GB"
  type        = number
  default     = 20
}
