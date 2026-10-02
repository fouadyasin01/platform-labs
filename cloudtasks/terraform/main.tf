data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project     = "cloudtasks"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# NETWORKING
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "cloudtasks-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "cloudtasks-igw"
  })
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "cloudtasks-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "app" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "cloudtasks-app-${count.index + 1}"
    Tier = "private-app"
  })
}

resource "aws_subnet" "db" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 21}.0/24"
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "cloudtasks-db-${count.index + 1}"
    Tier = "private-db"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "cloudtasks-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = 2

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "cloudtasks-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "cloudtasks-nat-${count.index + 1}"
  })
}

resource "aws_route_table" "app" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "cloudtasks-app-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "app" {
  count = 2

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "cloudtasks-db-rt"
  })
}

resource "aws_route_table_association" "db" {
  count = 2

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ============================================================
# SECURITY GROUPS
# ============================================================

resource "aws_security_group" "alb" {
  name        = "cloudtasks-alb-sg"
  description = "Security group for CloudTasks ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
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

  tags = merge(local.common_tags, {
    Name = "cloudtasks-alb-sg"
  })
}

resource "aws_security_group" "app" {
  name        = "cloudtasks-app-sg"
  description = "Security group for CloudTasks ECS application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API traffic from ALB"
    from_port       = 3000
    to_port         = 3000
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

  tags = merge(local.common_tags, {
    Name = "cloudtasks-app-sg"
  })
}

resource "aws_security_group" "rds" {
  name        = "cloudtasks-rds-sg"
  description = "Security group for CloudTasks PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from application"
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

  tags = merge(local.common_tags, {
    Name = "cloudtasks-rds-sg"
  })
}


# ============================================================
# RDS POSTGRESQL
# ============================================================

resource "aws_db_subnet_group" "postgres" {
  name       = "cloudtasks-postgres"
  subnet_ids = aws_subnet.db[*].id

  tags = merge(local.common_tags, {
    Name = "cloudtasks-postgres"
  })
}

resource "aws_db_instance" "postgres" {
  identifier = "cloudtasks-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "cloudtasks"
  username = "cloudtasks"
  password = var.db_password

  port = 5432

  multi_az = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  backup_retention_period = 1

  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "cloudtasks-postgres"
  })
}


# ============================================================
# ECS CLUSTER
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = "cloudtasks"

  tags = merge(local.common_tags, {
    Name = "cloudtasks-ecs"
  })
}

# ============================================================
# ECS IAM
# ============================================================

resource "aws_iam_role" "ecs_instance" {
  name = "cloudtasks-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "cloudtasks-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "cloudtasks-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================
# ECS OPTIMIZED AMI
# ============================================================

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}


# ============================================================
# ECS EC2 CAPACITY
# ============================================================

resource "aws_launch_template" "ecs" {
  name_prefix   = "cloudtasks-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash

    # Configure ECS cluster
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config

    # Start SSM Agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Install PostgreSQL 16 client
    dnf install -y postgresql16

    # Wait for PostgreSQL/RDS
    POSTGRES_READY=false

    for i in $(seq 1 60); do
      if PGPASSWORD='${var.db_password}' psql \
        -h '${aws_db_instance.postgres.address}' \
        -p 5432 \
        -U 'cloudtasks' \
        -d 'cloudtasks' \
        -c "SELECT 1;" >/dev/null 2>&1; then

        POSTGRES_READY=true
        echo "PostgreSQL is ready."
        break
      fi

      echo "Waiting for PostgreSQL..."
      sleep 10
    done

    if [ "$POSTGRES_READY" != "true" ]; then
      echo "PostgreSQL did not become ready."
      exit 1
    fi

    # Check whether tasks table exists
    TABLE_EXISTS=$(PGPASSWORD='${var.db_password}' psql \
      -h '${aws_db_instance.postgres.address}' \
      -p 5432 \
      -U 'cloudtasks' \
      -d 'cloudtasks' \
      -tAc "SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'tasks'
      );")

    if [ "$TABLE_EXISTS" = "t" ]; then
      echo "tasks table already exists. Nothing to do."
    else
      echo "tasks table does not exist. Creating it..."

      PGPASSWORD='${var.db_password}' psql \
        -h '${aws_db_instance.postgres.address}' \
        -p 5432 \
        -U 'cloudtasks' \
        -d 'cloudtasks' \
        -c "CREATE TABLE IF NOT EXISTS tasks (
          id SERIAL PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          completed BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );"

      echo "tasks table created."
    fi
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "cloudtasks-ecs"
    })
  }

  depends_on = [
    aws_db_instance.postgres
  ]
}

# ============================================================
# ECS AUTO SCALING GROUP
# ============================================================

resource "aws_autoscaling_group" "ecs" {
  depends_on = [
    aws_db_instance.postgres
  ]

  name = "cloudtasks-ecs-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = aws_subnet.app[*].id

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "cloudtasks-ecs"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

# ============================================================
# ECS CAPACITY PROVIDER
# ============================================================

resource "aws_ecs_capacity_provider" "main" {
  name = "cloudtasks-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }

    managed_termination_protection = "DISABLED"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    aws_ecs_capacity_provider.main.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }
}

# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================

resource "aws_lb" "main" {
  name               = "cloudtasks-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = aws_subnet.public[*].id

  tags = merge(local.common_tags, {
    Name = "cloudtasks-alb"
  })
}

resource "aws_lb_target_group" "api" {
  name        = "cloudtasks-api"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"

  vpc_id = aws_vpc.main.id

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


# ============================================================
# ECS API TASK
# ============================================================

resource "aws_ecs_task_definition" "api" {
  family = "cloudtasks-api"

  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "cloudtasks-api"
      image     = "vanbasten01/cloudtasks-api:1.1"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "3000"
        },
        {
          name  = "DB_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "DB_PORT"
          value = "5432"
        },
        {
          name  = "DB_NAME"
          value = "cloudtasks"
        },
        {
          name  = "DB_USER"
          value = "cloudtasks"
        },
        {
          name  = "DB_PASSWORD"
          value = var.db_password
        }
      ]
    }
  ])

  tags = local.common_tags
}

# ============================================================
# ECS SERVICE
# ============================================================

resource "aws_ecs_service" "api" {
  name            = "cloudtasks-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn

  desired_count = 2

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "cloudtasks-api"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.main
  ]

  tags = local.common_tags
}



# ============================================================
# FRONTEND HOSTING & CDN
# ============================================================

data "aws_caller_identity" "current" {}

locals {
  frontend_files = fileset(
    "${path.module}/../frontend/dist",
    "**"
  )
}

resource "aws_s3_bucket" "frontend" {
  bucket = "cloudtasks-frontend-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "cloudtasks-frontend"
  })
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_object" "frontend" {
  for_each = local.frontend_files

  bucket = aws_s3_bucket.frontend.id

  key    = each.value
  source = "${path.module}/../frontend/dist/${each.value}"

  etag = filemd5(
    "${path.module}/../frontend/dist/${each.value}"
  )

  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      svg  = "image/svg+xml"
      json = "application/json"
    },
    try(regex("\\.([^.]+)$", each.value)[0], ""),
    "application/octet-stream"
  )
}

# ============================================================
# CLOUDFRONT
# ============================================================

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "cloudtasks-frontend-oac"
  description                       = "OAC for CloudTasks frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"

  # Frontend: S3
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "cloudtasks-frontend-s3"

    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Backend API: ALB
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "cloudtasks-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"

      origin_ssl_protocols = [
        "TLSv1.2"
      ]
    }
  }

  # API requests -> ALB
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "cloudtasks-alb"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = true

      headers = [
        "Host"
      ]

      cookies {
        forward = "all"
      }
    }
  }

  # Everything else -> S3
  default_cache_behavior {
    target_origin_id       = "cloudtasks-frontend-s3"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(local.common_tags, {
    Name = "cloudtasks-frontend-cdn"
  })
}

# ============================================================
# S3 BUCKET POLICY
# ============================================================

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"

        Principal = {
          Service = "cloudfront.amazonaws.com"
        }

        Action = "s3:GetObject"

        Resource = "${aws_s3_bucket.frontend.arn}/*"

        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend
  ]
}