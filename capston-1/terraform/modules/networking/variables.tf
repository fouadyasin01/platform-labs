variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "capston-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the network"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "enable_nat_gateways" {
  description = "Whether to create one NAT Gateway per public subnet"
  type        = bool
  default     = true
}

variable "karpenter_discovery_cluster_name" {
  description = "EKS cluster name used for Karpenter subnet discovery"
  type        = string
}