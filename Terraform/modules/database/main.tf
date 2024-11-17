# RDS Subnet Group Configuration
resource "aws_db_subnet_group" "main" {
  name        = "ecommerce-db-subnet-group"
  description = "Database subnet group for ecommerce application"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "ecommerce-db-subnet-group"
  }
}

# RDS PostgreSQL Instance Configuration
resource "aws_db_instance" "main" {
  identifier             = "ecommerce-db"
  engine                 = "postgres"
  engine_version         = "14.10"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp2"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "ecommerce-db"
  }
}

# Outputs
output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "rds_db_name" {
  value = aws_db_instance.main.db_name
}

output "rds_sg_id" {
  value = var.rds_sg_id
}
