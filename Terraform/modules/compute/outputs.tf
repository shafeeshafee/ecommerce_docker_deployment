# modules/compute/outputs.tf

output "bastion_public_ips" {
  description = "Public IPs of bastion hosts"
  value       = aws_instance.bastion[*].public_ip
}

output "app_private_ips" {
  description = "Private IPs of application servers"
  value       = aws_instance.app[*].private_ip
}

output "app_instance_ids" {
  description = "IDs of application servers"
  value       = aws_instance.app[*].id
}
