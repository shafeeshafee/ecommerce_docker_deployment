data "aws_vpc" "default" {
  default = true
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

# VPC peering
resource "aws_vpc_peering_connection" "peer_default" {
  vpc_id      = aws_vpc.main.id
  peer_vpc_id = var.default_vpc_id
  auto_accept = true

  tags = {
    Name = "peer_custom_to_default"
  }
}

resource "aws_route" "private_to_default_vpc" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer_default.id
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

  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "172.31.0.0/16"]
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

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = {
    "az1" = aws_subnet.public_1.id
    "az2" = aws_subnet.public_2.id
  }
}

output "private_subnet_ids" {
  value = {
    "az1" = aws_subnet.private_1.id
    "az2" = aws_subnet.private_2.id
  }
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.peer_default.id
}
