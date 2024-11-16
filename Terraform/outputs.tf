# outputs.tf

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.load_balancer.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the application load balancer"
  value       = module.load_balancer.alb_zone_id
}

# RDS Outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = module.database.rds_endpoint
}

# Bastion Host Outputs
output "bastion_public_ips" {
  description = "Public IPs of bastion hosts"
  value       = module.compute.bastion_public_ips
}

# Application Server Outputs
output "app_private_ips" {
  description = "Private IPs of application servers"
  value       = module.compute.app_private_ips
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

# Security Group Outputs
output "bastion_sg_id" {
  description = "ID of bastion host security group"
  value       = module.security_groups.bastion_sg_id
}

output "app_sg_id" {
  description = "ID of application security group"
  value       = module.security_groups.app_sg_id
}

output "rds_sg_id" {
  description = "ID of RDS security group"
  value       = module.security_groups.rds_sg_id
}

# Target Group Outputs
output "frontend_target_group_arn" {
  description = "ARN of frontend target group"
  value       = module.load_balancer.frontend_target_group_arn
}

output "backend_target_group_arn" {
  description = "ARN of backend target group"
  value       = module.load_balancer.backend_target_group_arn
}

# Application URLs
output "frontend_url" {
  description = "URL for frontend application"
  value       = "http://${module.load_balancer.alb_dns_name}"
}

output "backend_url" {
  description = "URL for backend application"
  value       = "http://${module.load_balancer.alb_dns_name}/admin/"
}
