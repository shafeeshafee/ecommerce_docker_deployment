# Application Load Balancer (ALB) Configuration
resource "aws_lb" "main" {
  name               = "ecommerce-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = [var.public_subnet_ids["az1"], var.public_subnet_ids["az2"]]

  tags = {
    Name = "ecommerce-alb"
  }
}

# ALB Target Group for Frontend Services
resource "aws_lb_target_group" "frontend" {
  name     = "ecommerce-frontend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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
  vpc_id   = var.vpc_id

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
  subnet_id     = var.public_subnet_ids["az1"]
  key_name      = var.key_name

  vpc_security_group_ids = [var.bastion_sg_id]

  tags = {
    Name = "ecommerce_bastion_az1"
  }
}

# EC2 Instance Configuration for Bastion Host in Availability Zone 2
resource "aws_instance" "bastion_az2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_bastion
  subnet_id     = var.public_subnet_ids["az2"]
  key_name      = var.key_name

  vpc_security_group_ids = [var.bastion_sg_id]

  tags = {
    Name = "ecommerce_bastion_az2"
  }
}

# EC2 Instance Configuration for Application Server in AZ1
resource "aws_instance" "app_az1" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_app
  subnet_id     = var.private_subnet_ids["az1"]
  key_name      = var.key_name

  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_address = var.rds_address
    db_username = var.db_username
    db_password = var.db_password
    docker_user = var.dockerhub_username
    docker_pass = var.dockerhub_password
    docker_compose = templatefile("${path.module}/compose.yml", {
      rds_address = var.rds_address
      db_username = var.db_username
      db_password = var.db_password
    })
  }))

  depends_on = [aws_lb.main]

  tags = {
    Name = "ecommerce_app_az1"
  }
}

# EC2 Instance Configuration for Application Server in AZ2
resource "aws_instance" "app_az2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS AMI
  instance_type = var.instance_type_app
  subnet_id     = var.private_subnet_ids["az2"]
  key_name      = var.key_name

  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_address = var.rds_address
    db_username = var.db_username
    db_password = var.db_password
    docker_user = var.dockerhub_username
    docker_pass = var.dockerhub_password
    docker_compose = templatefile("${path.module}/compose.yml", {
      rds_address = var.rds_address
      db_username = var.db_username
      db_password = var.db_password
    })
  }))

  depends_on = [aws_lb.main]

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

# Outputs
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "bastion_az1_public_ip" {
  value = aws_instance.bastion_az1.public_ip
}

output "bastion_az2_public_ip" {
  value = aws_instance.bastion_az2.public_ip
}

output "app_az1_private_ip" {
  value = aws_instance.app_az1.private_ip
}

output "app_az2_private_ip" {
  value = aws_instance.app_az2.private_ip
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend.arn
}
