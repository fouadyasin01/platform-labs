resource "aws_db_subnet_group" "database" {
  name = "${var.project_name}-${var.environment}-db"

  subnet_ids = [
    aws_subnet.database[0].id,
    aws_subnet.database[1].id
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
    Tier = "database"
  }
}

resource "aws_db_instance" "database" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "appdb"
  username = "appadmin"
  password = var.database_password

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]

  multi_az            = true
  publicly_accessible = false

  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
    Tier = "database"
  }
}