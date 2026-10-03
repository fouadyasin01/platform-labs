
# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================


locals {
  common_tags = {
    Project     = "cloudtasks"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_lb" "main" {
  name               = "cloudtasks-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.sg_alb_id
  ]

  subnets = var.public_subnets[*].id

  tags = merge(local.common_tags, {
    Name = "cloudtasks-alb"
  })
}

resource "aws_lb_target_group" "api" {
  name        = "cloudtasks-api"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"

  vpc_id = var.vpc_id

  health_check {
    enabled  = true
    path     = "/api/health"
    protocol = "HTTP"
    port     = "3000"

    healthy_threshold   = 2
    unhealthy_threshold = 3

    interval = 30
    timeout  = 5

    matcher = "200"
  }

  tags = merge(local.common_tags, {
    Name = "cloudtasks-api"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

