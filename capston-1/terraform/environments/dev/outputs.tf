output "aws_account_id" {
  description = "AWS account ID Terraform is using"
  value       = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.networking.nat_gateway_ids
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_node_group_name" {
  description = "Name of the EKS baseline managed node group"
  value       = module.eks.node_group_name
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = module.eks.node_role_arn
}
