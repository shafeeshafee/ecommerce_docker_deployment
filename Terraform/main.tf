terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

# Provider configuration specifying the AWS region to deploy resources
provider "aws" {
  region = "us-east-1"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ecommerce-vpc"
  }
}

# Internet Gateway Configuration
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ecommerce-igw"
  }
}

# Public Subnets Configuration
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs["us-east-1a"]
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecommerce-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs["us-east-1b"]
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecommerce-public-2"
  }
}

# Private Subnets Configuration
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs["us-east-1a"]
  availability_zone = "us-east-1a"

  tags = {
    Name = "ecommerce-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs["us-east-1b"]
  availability_zone = "us-east-1b"

  tags = {
    Name = "ecommerce-private-2"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway Configuration
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "ecommerce-nat"
  }
}

# Public Route Table Configuration
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "ecommerce-public-rt"
  }
}

# Private Route Table Configuration
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "ecommerce-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Bastion Hosts
resource "aws_security_group" "bastion" {
  name        = "ecommerce-bastion-sg"
  description = "Security group for bastion hosts"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-bastion-sg"
  }
}

# Security Group for Application Servers
resource "aws_security_group" "app" {
  name        = "ecommerce-app-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "Allow port 3000 for frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow port 8000 for backend"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-app-sg"
  }
}

# Security Group for RDS Database
resource "aws_security_group" "rds" {
  name        = "ecommerce-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from application servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-rds-sg"
  }
}

# RDS Subnet Group Configuration
resource "aws_db_subnet_group" "main" {
  name        = "ecommerce-db-subnet-group"
  description = "Database subnet group for ecommerce application"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

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
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "ecommerce-db"
  }
}

# Security Group for Application Load Balancer (ALB)
resource "aws_security_group" "alb" {
  name        = "ecommerce-alb-sg"
  description = "Security group for application load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-alb-sg"
  }
}

# Application Load Balancer (ALB) Configuration
resource "aws_lb" "main" {
  name               = "ecommerce-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "ecommerce-alb"
  }
}

# ALB Target Group for Frontend Services
resource "aws_lb_target_group" "frontend" {
  name     = "ecommerce-frontend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    interval            = 30
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200-299"
  }
}

# ALB Target Group for Backend Services
resource "aws_lb_target_group" "backend" {
  name     = "ecommerce-backend-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/admin/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    interval            = 30
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200-299"
  }
}

# ALB Listener for Frontend Traffic
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ALB Listener Rule for Backend Traffic
resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.frontend.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/admin/*", "/api/*"]
    }
  }
}

# EC2 Instance Configuration for Bastion Host in Availability Zone 1
resource "aws_instance" "bastion_az1" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_bastion
  subnet_id     = aws_subnet.public_1.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "ecommerce_bastion_az1"
  }
}

# EC2 Instance Configuration for Bastion Host in Availability Zone 2
resource "aws_instance" "bastion_az2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_bastion
  subnet_id     = aws_subnet.public_2.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "ecommerce_bastion_az2"
  }
}

# EC2 Instance Configuration for Application Server in AZ1
resource "aws_instance" "app_az1" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_app
  subnet_id     = aws_subnet.private_1.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_address = aws_db_instance.main.address
    db_username = var.db_username
    db_password = var.db_password
    docker_user = var.dockerhub_username
    docker_pass = var.dockerhub_password
    docker_compose = templatefile("${path.module}/compose.yml", {
      rds_address = aws_db_instance.main.address
      db_username = var.db_username
      db_password = var.db_password
    })
  }))

  depends_on = [
    aws_db_instance.main,
    aws_nat_gateway.main
  ]

  tags = {
    Name = "ecommerce_app_az1"
  }
}

# EC2 Instance Configuration for Application Server in AZ2
resource "aws_instance" "app_az2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_app
  subnet_id     = aws_subnet.private_2.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_address = aws_db_instance.main.address
    db_username = var.db_username
    db_password = var.db_password
    docker_user = var.dockerhub_username
    docker_pass = var.dockerhub_password
    docker_compose = templatefile("${path.module}/compose.yml", {
      rds_address = aws_db_instance.main.address
      db_username = var.db_username
      db_password = var.db_password
    })
  }))

  depends_on = [
    aws_db_instance.main,
    aws_nat_gateway.main
  ]

  tags = {
    Name = "ecommerce_app_az2"
  }
}


# ALB Target Group Attachments for Frontend in AZ1
resource "aws_lb_target_group_attachment" "frontend_az1" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.app_az1.id
  port             = 3000
}

# ALB Target Group Attachments for Frontend in AZ2
resource "aws_lb_target_group_attachment" "frontend_az2" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.app_az2.id
  port             = 3000
}

# ALB Target Group Attachments for Backend in AZ1
resource "aws_lb_target_group_attachment" "backend_az1" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.app_az1.id
  port             = 8000
}

# ALB Target Group Attachments for Backend in AZ2
resource "aws_lb_target_group_attachment" "backend_az2" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.app_az2.id
  port             = 8000
}
