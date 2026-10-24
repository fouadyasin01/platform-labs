variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "prod-cicd-sec"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.40.0.0/20", "10.40.16.0/20", "10.40.32.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.40.48.0/20", "10.40.64.0/20", "10.40.80.0/20"]
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Public IP CIDRs allowed to reach the EKS API endpoint"
  type        = list(string)
  sensitive   = true
}
