# =========================================================
# Public Application Load Balancer
# =========================================================
# Internet-facing ALB that provides the single public entry
# point for the application.
#
# Traffic flow:
# Internet -> Public ALB -> Nginx web tier
#
# The ALB is deployed across both public subnets for
# high availability.

resource "aws_lb" "public" {
  name               = "${var.project_name}-${var.environment}-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-public-alb"
    Tier = "public"
  }
}

# Target group for the Nginx web tier.
# EC2 instances will be registered here when the web tier
# is implemented.

resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-${var.environment}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-tg"
    Tier = "web"
  }
}

# Public ALB listener.
# HTTP traffic is forwarded to the Nginx web tier.
#
# HTTPS can be added later with an ACM certificate and
# an HTTPS listener on port 443.

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# =========================================================
# Internal Application Load Balancer
# =========================================================
# Internal ALB used to decouple the Nginx web tier from the
# Node.js application tier.
#
# Traffic flow:
# Nginx -> Internal ALB -> Node.js application
#
# The ALB is internal and therefore has no public Internet
# endpoint.

resource "aws_lb" "app" {
  name               = "${var.project_name}-${var.environment}-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_alb.id]
  subnets            = aws_subnet.app[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-app-alb"
    Tier = "app"
  }
}

# Target group for the Node.js application tier.
# Application instances will be registered here when the
# application EC2 tier is implemented.

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-${var.environment}-app-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/api/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-tg"
    Tier = "app"
  }
}

# Internal ALB listener.
# HTTP requests from the Nginx tier are forwarded to the
# Node.js application instances on port 3000.

resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
