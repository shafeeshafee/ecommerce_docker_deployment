# modules/database/main.tf

# RDS Subnet Group Configuration
resource "aws_db_subnet_group" "main" {
  name        = var.db_subnet_group_name
  description = "Database subnet group for ecommerce application"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = var.db_subnet_group_name
  }
}

# RDS PostgreSQL Instance Configuration
resource "aws_db_instance" "main" {
  identifier             = var.db_identifier
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = var.db_storage_type
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = var.db_identifier
  }
}
