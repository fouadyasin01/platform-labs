# ============================================================
# ECS CLUSTER
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-ecs"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ecs"
  })
}

# ============================================================
# ECS IAM
# ============================================================

resource "aws_iam_role" "ecs_instance" {
  name = "${var.name_prefix}-ecs-instance-role"

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

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.name_prefix}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name

  tags = var.common_tags
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name_prefix}-ecs-task-execution-role"

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

  tags = var.common_tags
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
  name_prefix   = "${var.name_prefix}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    var.sg_app_id
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
        -h '${var.postgres_instance_address}' \
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
      -h '${var.postgres_instance_address}' \
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
        -h '${var.postgres_instance_address}' \
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

    tags = merge(var.common_tags, {
      Name = "${var.name_prefix}-ecs"
    })
  }

  depends_on = [
    var.postgres_instance
  ]
}
# ============================================================
# ECS AUTO SCALING GROUP
# ============================================================

resource "aws_autoscaling_group" "ecs" {
  depends_on = [
    var.postgres_instance
  ]

  name = "${var.name_prefix}-ecs-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = var.subnets_app[*].id

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-ecs"
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
  name = "${var.name_prefix}-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }

    managed_termination_protection = "DISABLED"
  }

  tags = var.common_tags
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
# ECS API TASK
# ============================================================

resource "aws_ecs_task_definition" "api" {
  family = "${var.name_prefix}-api"

  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "${var.name_prefix}-api"
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
          value = var.postgres_instance_address
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

  tags = var.common_tags
}

# ============================================================
# ECS SERVICE
# ============================================================

resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn

  desired_count = 2

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = var.lb_target_group_arn
    container_name   = "${var.name_prefix}-api"
    container_port   = 3000
  }

  depends_on = [
    var.aws_lb_listener_http,
    aws_ecs_cluster_capacity_providers.main
  ]

  tags = var.common_tags
}