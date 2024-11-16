# modules/database/variables.tf

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "Name for the DB subnet group"
  type        = string
  default     = "ecommerce-db-subnet-group"
}

variable "db_identifier" {
  description = "Identifier for the RDS database"
  type        = string
  default     = "ecommerce-db"
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "14.10"
}

variable "db_instance_class" {
  description = "Instance class for RDS database"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS database in GB"
  type        = number
}

variable "db_storage_type" {
  description = "Storage type for RDS database"
  type        = string
  default     = "gp2"
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "rds_security_group_id" {
  description = "Security Group ID for RDS"
  type        = string
}
