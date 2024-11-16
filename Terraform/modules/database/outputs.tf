# modules/database/outputs.tf

output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "The address of the RDS database"
  value       = aws_db_instance.main.address
}
