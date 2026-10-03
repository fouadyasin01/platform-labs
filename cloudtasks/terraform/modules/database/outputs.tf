output "db_instance" {
  value = aws_db_instance.postgres
}

output "db_instance_address" {
  value = aws_db_instance.postgres.address
}



