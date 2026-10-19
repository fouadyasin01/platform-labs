output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  value = module.networking.vpc_id
}
output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}
output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}
output "nat_gateway_ids" {
  value = module.networking.nat_gateway_ids
}