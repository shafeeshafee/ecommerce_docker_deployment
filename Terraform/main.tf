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
# Creates a custom Virtual Private Cloud (VPC) with a CIDR block of 10.0.0.0/16
# Enables DNS hostnames and DNS support for the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ecommerce-vpc"
  }
}

# Internet Gateway Configuration
# Attaches an Internet Gateway to the VPC to allow internet access for resources in public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ecommerce-igw"
  }
}

# Public Subnets Configuration
# Creates two public subnets in different Availability Zones (AZs) for high availability
# Public subnets are used for resources that need direct internet access, like bastion hosts
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecommerce-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecommerce-public-2"
  }
}

# Private Subnets Configuration
# Creates two private subnets in different AZs for deploying application servers
# Private subnets do not have direct internet access and are used for backend services
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ecommerce-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "ecommerce-private-2"
  }
}

# Elastic IP for NAT Gateway
# Allocates an Elastic IP address for the NAT Gateway to enable internet access for resources in private subnets
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway Configuration
# Creates a NAT Gateway in the first public subnet to allow instances in private subnets to access the internet
# This is essential for downloading updates or accessing external services without exposing the instances directly
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "ecommerce-nat"
  }
}

# Public Route Table Configuration
# Defines routing rules for the public subnets, directing outbound traffic to the Internet Gateway
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
# Defines routing rules for the private subnets, directing outbound traffic through the NAT Gateway
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
# Associates each subnet with its corresponding route table to apply the routing rules
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
# Defines inbound and outbound rules for bastion hosts, allowing SSH access from anywhere
# Bastion hosts are used as secure entry points for managing instances in private subnets
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
# Defines inbound rules to allow SSH access from bastion hosts and HTTP/HTTPS traffic
# Allows communication with the RDS database and exposure of frontend and backend services
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
# Allows inbound PostgreSQL traffic only from the application servers' security group
# Ensures that the database is not exposed publicly and only accessible by authorized instances
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

  tags = {
    Name = "ecommerce-rds-sg"
  }
}

# RDS Subnet Group Configuration
# Groups the private subnets for the RDS instance to ensure it resides in a secure, private environment
resource "aws_db_subnet_group" "main" {
  name        = "ecommerce-db-subnet-group"
  description = "Database subnet group for ecommerce application"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "ecommerce-db-subnet-group"
  }
}

# RDS PostgreSQL Instance Configuration
# Sets up a PostgreSQL database instance with specified credentials and security settings
# Ensures the database is only accessible within the VPC and not publicly exposed
resource "aws_db_instance" "main" {
  identifier             = "ecommerce-db"
  engine                 = "postgres"
  engine_version         = "14.10"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
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
# Allows HTTP traffic from anywhere and manages outbound traffic
# The ALB will distribute incoming traffic to the frontend and backend target groups
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
# Sets up an ALB to distribute incoming HTTP traffic across multiple availability zones
# Enhances application availability and fault tolerance
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
# Defines a target group for frontend instances listening on port 3000
# Includes health check configurations to monitor the health of frontend services
resource "aws_lb_target_group" "frontend" {
  name     = "ecommerce-frontend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# ALB Target Group for Backend Services
# Defines a target group for backend instances listening on port 8000
# Includes health check configurations to monitor the health of backend services
resource "aws_lb_target_group" "backend" {
  name     = "ecommerce-backend-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/admin/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# ALB Listener for Frontend Traffic
# Listens on port 80 (HTTP) and forwards traffic to the frontend target group by default
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
# Defines routing rules based on URL path patterns to direct traffic to backend services
# Traffic matching "/admin/*" or "/api/*" is forwarded to the backend target group
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
# Sets up a bastion host in the first public subnet for secure SSH access to private instances
resource "aws_instance" "bastion_az1" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_1.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "ecommerce_bastion_az1"
  }
}

# EC2 Instance Configuration for Bastion Host in Availability Zone 2
# Sets up a second bastion host in another public subnet for high availability
resource "aws_instance" "bastion_az2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_2.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "ecommerce_bastion_az2"
  }
}

# EC2 Instance Configuration for Application Server in AZ1
# Deploys an application server in the first private subnet
# Executes a deployment script to set up Docker, pull images, and run containers
resource "aws_instance" "app_az1" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.private_1.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  # User data script to initialize the instance with Docker and deploy the application
  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_endpoint = aws_db_instance.main.endpoint
    docker_user  = var.dockerhub_username
    docker_pass  = var.dockerhub_password
    docker_compose = templatefile("${path.module}/compose.yml", {
      rds_endpoint = aws_db_instance.main.endpoint
    })
  }))

  # Ensures that the RDS instance and NAT Gateway are created before this instance
  depends_on = [
    aws_db_instance.main,
    aws_nat_gateway.main
  ]

  tags = {
    Name = "ecommerce_app_az1"
  }
}

# EC2 Instance Configuration for Application Server in AZ2
# Deploys a second application server in the second private subnet for load balancing and redundancy
resource "aws_instance" "app_az2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.private_2.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  # User data script to initialize the instance with Docker and deploy the application
  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_endpoint = aws_db_instance.main.endpoint
    docker_user  = var.dockerhub_username
    docker_pass  = var.dockerhub_password
    docker_compose = templatefile("${path.module}/compose.yml", {
      rds_endpoint = aws_db_instance.main.endpoint
    })
  }))

  # Ensures that the RDS instance and NAT Gateway are created before this instance
  depends_on = [
    aws_db_instance.main,
    aws_nat_gateway.main
  ]

  tags = {
    Name = "ecommerce_app_az2"
  }
}

# ALB Target Group Attachments for Frontend in AZ1
# Associates the first application server with the frontend target group on port 3000
resource "aws_lb_target_group_attachment" "frontend_az1" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.app_az1.id
  port             = 3000
}

# ALB Target Group Attachments for Frontend in AZ2
# Associates the second application server with the frontend target group on port 3000
resource "aws_lb_target_group_attachment" "frontend_az2" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.app_az2.id
  port             = 3000
}

# ALB Target Group Attachments for Backend in AZ1
# Associates the first application server with the backend target group on port 8000
resource "aws_lb_target_group_attachment" "backend_az1" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.app_az1.id
  port             = 8000
}

# ALB Target Group Attachments for Backend in AZ2
# Associates the second application server with the backend target group on port 8000
resource "aws_lb_target_group_attachment" "backend_az2" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.app_az2.id
  port             = 8000
}
