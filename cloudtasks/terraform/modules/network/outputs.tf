output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public
}

output "db_subnets" {
  value = aws_subnet.db
}

output "app_subnets" {
  value = aws_subnet.app
}


