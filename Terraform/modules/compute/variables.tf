# modules/compute/variables.tf

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "bastion_security_group_id" {
  description = "Security Group ID for Bastion Hosts"
  type        = string
}

variable "app_security_group_id" {
  description = "Security Group ID for Application Servers"
  type        = string
}

variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string
}

variable "instance_type_bastion" {
  description = "Instance type for bastion hosts"
  type        = string
}

variable "instance_type_app" {
  description = "Instance type for application servers"
  type        = string
}

variable "bastion_ami" {
  description = "AMI ID for Bastion Hosts"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
}

variable "app_ami" {
  description = "AMI ID for Application Servers"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
}

variable "bastion_name" {
  description = "Name prefix for Bastion Hosts"
  type        = string
  default     = "ecommerce_bastion"
}

variable "app_name" {
  description = "Name prefix for Application Servers"
  type        = string
  default     = "ecommerce_app"
}

variable "rds_address" {
  description = "Address of the RDS database"
  type        = string
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "dockerhub_username" {
  description = "DockerHub username for pulling container images"
  type        = string
}

variable "dockerhub_password" {
  description = "DockerHub password for pulling container images"
  type        = string
  sensitive   = true
}

variable "deploy_script_path" {
  description = "Path to the deploy.sh script"
  type        = string
}

variable "compose_template_path" {
  description = "Path to the compose.yml template"
  type        = string
}
