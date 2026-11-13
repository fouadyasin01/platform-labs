output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster certificate authority data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "node_group_name" {
  description = "Name of the baseline managed node group"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN for worker nodes"
  value       = aws_iam_role.node.arn
}


output "loki_iam_role_arn" {
  description = "IAM role ARN used by Loki through IRSA"
  value       = aws_iam_role.loki.arn
}

output "loki_chunks_bucket" {
  description = "S3 bucket for Loki chunks"
  value       = aws_s3_bucket.loki["chunks"].bucket
}

output "loki_ruler_bucket" {
  description = "S3 bucket for Loki ruler data"
  value       = aws_s3_bucket.loki["ruler"].bucket
}