output "monitoring_instance_ip" {
  description = "Public IP of monitoring instance"
  value       = aws_instance.monitoring.public_ip
}

output "monitoring_sg_id" {
  description = "ID of monitoring security group"
  value       = aws_security_group.monitoring.id
}
