# modules/load_balancer/main.tf

# Application Load Balancer (ALB) Configuration
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = var.alb_name
  }
}

# ALB Target Group for Frontend Services
resource "aws_lb_target_group" "frontend" {
  name     = var.frontend_tg_name
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
  name     = var.backend_tg_name
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

# ALB Target Group Attachments for Frontend
resource "aws_lb_target_group_attachment" "frontend" {
  count            = length(var.app_instance_ids)
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = var.app_instance_ids[count.index]
  port             = 3000
}

# ALB Target Group Attachments for Backend
resource "aws_lb_target_group_attachment" "backend" {
  count            = length(var.app_instance_ids)
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = var.app_instance_ids[count.index]
  port             = 8000
}
