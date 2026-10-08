# Security groups enforce least-privilege communication between
# the Internet, load balancers, application tiers, and database.

# =========================================================
# Public Application Load Balancer
# =========================================================
# Allows HTTP/HTTPS traffic from the Internet to the
# internet-facing ALB.

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for the public Application Load Balancer"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow HTTP from the Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from the Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Tier = "public"
  }
}

# =========================================================
# Web Tier
# =========================================================
# Only the public ALB can send HTTP traffic to the
# Nginx web tier.

resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Security group for the Nginx web tier"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow HTTP from public ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-sg"
    Tier = "web"
  }
}

# =========================================================
# Internal Application Load Balancer
# =========================================================
# The internal ALB is reachable only from the Nginx web tier.
# It is never exposed directly to the Internet.

resource "aws_security_group" "app_alb" {
  name        = "${var.project_name}-${var.environment}-app-alb-sg"
  description = "Security group for the internal application load balancer"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow HTTP from web tier"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-alb-sg"
    Tier = "app"
  }
}

# =========================================================
# Application Tier
# =========================================================
# Only the internal application ALB can connect to the
# Node.js application on port 3000.

resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for the Node.js application tier"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow Node.js traffic from internal ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.app_alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-sg"
    Tier = "app"
  }
}

# =========================================================
# Database Tier
# =========================================================
# PostgreSQL is accessible only from the application tier.
# No Internet-facing access is permitted.

resource "aws_security_group" "database" {
  name        = "${var.project_name}-${var.environment}-database-sg"
  description = "Security group for the PostgreSQL database tier"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow PostgreSQL from application tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-database-sg"
    Tier = "database"
  }
}
