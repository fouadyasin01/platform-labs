output "vpc_id" {
  description = "Created VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Created public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Created private subnet IDs"
  value       = module.networking.private_subnet_ids
}
