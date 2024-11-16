# modules/security_groups/variables.tf

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "bastion_sg_name" {
  description = "Name for the Bastion Security Group"
  type        = string
  default     = "ecommerce-bastion-sg"
}

variable "app_sg_name" {
  description = "Name for the Application Security Group"
  type        = string
  default     = "ecommerce-app-sg"
}

variable "rds_sg_name" {
  description = "Name for the RDS Security Group"
  type        = string
  default     = "ecommerce-rds-sg"
}

variable "alb_sg_name" {
  description = "Name for the ALB Security Group"
  type        = string
  default     = "ecommerce-alb-sg"
}
