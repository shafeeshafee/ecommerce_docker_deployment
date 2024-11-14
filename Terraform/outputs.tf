# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the application load balancer"
  value       = aws_lb.main.zone_id
}

# RDS Outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.main.endpoint
}

output "rds_db_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

# Bastion Host Outputs
output "bastion_az1_public_ip" {
  description = "Public IP of bastion host in AZ1"
  value       = aws_instance.bastion_az1.public_ip
}

output "bastion_az2_public_ip" {
  description = "Public IP of bastion host in AZ2"
  value       = aws_instance.bastion_az2.public_ip
}

# Application Server Outputs
output "app_az1_private_ip" {
  description = "Private IP of application server in AZ1"
  value       = aws_instance.app_az1.private_ip
}

output "app_az2_private_ip" {
  description = "Private IP of application server in AZ2"
  value       = aws_instance.app_az2.private_ip
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of public subnets"
  value = {
    "az1" = aws_subnet.public_1.id
    "az2" = aws_subnet.public_2.id
  }
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value = {
    "az1" = aws_subnet.private_1.id
    "az2" = aws_subnet.private_2.id
  }
}

# Security Group Outputs
output "bastion_sg_id" {
  description = "ID of bastion host security group"
  value       = aws_security_group.bastion.id
}

output "app_sg_id" {
  description = "ID of application security group"
  value       = aws_security_group.app.id
}

output "rds_sg_id" {
  description = "ID of RDS security group"
  value       = aws_security_group.rds.id
}

# Target Group Outputs
output "frontend_target_group_arn" {
  description = "ARN of frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  description = "ARN of backend target group"
  value       = aws_lb_target_group.backend.arn
}

# Connection Strings
output "ssh_bastion_az1" {
  description = "SSH command for bastion host in AZ1"
  value       = "ssh -i your-key.pem ubuntu@${aws_instance.bastion_az1.public_ip}"
}

output "ssh_bastion_az2" {
  description = "SSH command for bastion host in AZ2"
  value       = "ssh -i your-key.pem ubuntu@${aws_instance.bastion_az2.public_ip}"
}

# Application URLs
output "frontend_url" {
  description = "URL for frontend application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "backend_url" {
  description = "URL for backend application"
  value       = "http://${aws_lb.main.dns_name}/admin/"
}
