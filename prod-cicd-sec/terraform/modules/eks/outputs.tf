output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Custom cluster security group ID"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Worker-node security group ID"
  value       = aws_security_group.nodes.id
}

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.this.node_group_name
}
