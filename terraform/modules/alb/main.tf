terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_lb" "this" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnets
  idle_timeout       = 60

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-alb" }
  )
}

resource "aws_lb_target_group" "app" {
  name        = "${var.environment}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/actuator/health" # Spring Boot actuator endpoint
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }

  tags = merge(var.common_tags, { Name = "${var.environment}-tg" })
}

# HTTP listener ALWAYS exists (with conditional redirect)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # 🔑 FREE TIER FIX: Only redirect to HTTPS if certificate exists
  dynamic "default_action" {
    for_each = var.ssl_certificate_arn != null ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  # Fallback: Forward to app if no HTTPS
  dynamic "default_action" {
    for_each = var.ssl_certificate_arn == null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }
}

resource "aws_lb_listener" "https" {
   # 🔑 FREE TIER FIX: Only create if certificate ARN provided
  count = var.ssl_certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.ssl_certificate_arn # ACM certificate ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Target group ARN for ASG attachment"
  value       = aws_lb_target_group.app.arn
}
