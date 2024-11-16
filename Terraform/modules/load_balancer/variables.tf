# modules/load_balancer/variables.tf

variable "alb_security_group_id" {
  description = "Security Group ID for ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "app_instance_ids" {
  description = "List of Application EC2 Instance IDs"
  type        = list(string)
}

variable "alb_name" {
  description = "Name of the ALB"
  type        = string
  default     = "ecommerce-alb"
}

variable "frontend_tg_name" {
  description = "Name of the Frontend Target Group"
  type        = string
  default     = "ecommerce-frontend-tg"
}

variable "backend_tg_name" {
  description = "Name of the Backend Target Group"
  type        = string
  default     = "ecommerce-backend-tg"
}
