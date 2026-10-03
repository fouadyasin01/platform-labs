# ============================================================
# RDS POSTGRESQL
# ============================================================

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.name_prefix}-postgres"
  subnet_ids = var.db_subnets[*].id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-postgres"
  })
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.name_prefix}-postgres"

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
  vpc_security_group_ids = [var.sg_db_id]

  publicly_accessible = false

  backup_retention_period = 1

  skip_final_snapshot = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-postgres"
  })
}