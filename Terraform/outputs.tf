# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the application load balancer"
  value       = module.compute.alb_zone_id
}

# RDS Outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = module.database.rds_endpoint
}

output "rds_db_name" {
  description = "The database name"
  value       = module.database.rds_db_name
}

# Bastion Host Outputs
output "bastion_az1_public_ip" {
  description = "Public IP of bastion host in AZ1"
  value       = module.compute.bastion_az1_public_ip
}

output "bastion_az2_public_ip" {
  description = "Public IP of bastion host in AZ2"
  value       = module.compute.bastion_az2_public_ip
}

# Application Server Outputs
output "app_az1_private_ip" {
  description = "Private IP of application server in AZ1"
  value       = module.compute.app_az1_private_ip
}

output "app_az2_private_ip" {
  description = "Private IP of application server in AZ2"
  value       = module.compute.app_az2_private_ip
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
  value       = module.network.bastion_sg_id
}

output "app_sg_id" {
  description = "ID of application security group"
  value       = module.network.app_sg_id
}

output "rds_sg_id" {
  description = "ID of RDS security group"
  value       = module.network.rds_sg_id
}

# Target Group Outputs
output "frontend_target_group_arn" {
  description = "ARN of frontend target group"
  value       = module.compute.frontend_target_group_arn
}

output "backend_target_group_arn" {
  description = "ARN of backend target group"
  value       = module.compute.backend_target_group_arn
}

# Connection Strings
output "ssh_bastion_az1" {
  description = "SSH command for bastion host in AZ1"
  value       = "ssh -i your-key.pem ubuntu@${module.compute.bastion_az1_public_ip}"
}

output "ssh_bastion_az2" {
  description = "SSH command for bastion host in AZ2"
  value       = "ssh -i your-key.pem ubuntu@${module.compute.bastion_az2_public_ip}"
}

# Application URLs
output "frontend_url" {
  description = "URL for frontend application"
  value       = "http://${module.compute.alb_dns_name}"
}

output "backend_url" {
  description = "URL for backend application"
  value       = "http://${module.compute.alb_dns_name}/admin/"
}
