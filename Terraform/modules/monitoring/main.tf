# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch the main route table of the default VPC
data "aws_route_table" "default_main" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# Fetch all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for Monitoring Instance in the default VPC
resource "aws_security_group" "monitoring" {
  name        = "ecommerce-monitoring-sg"
  description = "Security group for monitoring instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
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
    Name = "ecommerce-monitoring-sg"
  }
}

# Monitoring Instance in the default VPC
resource "aws_instance" "monitoring" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  subnet_id              = data.aws_subnets.default.ids[0] # Use the first subnet in the default VPC

  user_data = base64encode(templatefile("${path.module}/scripts/prometheus_setup.sh", {
    app_ips = jsonencode(var.app_private_ips)
  }))

  tags = {
    Name = "ecommerce-monitoring"
  }
}

resource "aws_route" "default_to_custom_vpc" {
  route_table_id            = data.aws_route_table.default_main.id
  destination_cidr_block    = var.custom_vpc_cidr
  vpc_peering_connection_id = var.peering_connection_id
}
