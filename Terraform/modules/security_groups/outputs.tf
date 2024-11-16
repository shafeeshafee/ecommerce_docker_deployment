# modules/security_groups/outputs.tf

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

output "alb_sg_id" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}
