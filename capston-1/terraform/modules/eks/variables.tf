variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS cluster and worker nodes"
  type        = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks permitted to access the public Kubernetes API endpoint"
  type        = list(string)

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "At least one public API endpoint CIDR must be provided."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the baseline managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of baseline worker nodes"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired number of baseline worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of baseline worker nodes"
  type        = number
  default     = 3
}
