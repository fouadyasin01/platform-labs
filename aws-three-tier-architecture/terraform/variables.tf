# AWS deployment region.
variable "aws_region" {
  description = "AWS region where the infrastructure will be deployed"
  type        = string
  default     = "us-east-1"
}

# Deployment environment used for resource naming and tagging.
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

# Project identifier used in resource names and tags.
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "aws-three-tier"
}

# CIDR block for the entire VPC.
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# CIDR blocks for public subnets.
variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# CIDR blocks for private web subnets.
variable "web_subnet_cidrs" {
  description = "CIDR blocks for the private web subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# CIDR blocks for private application subnets.
variable "app_subnet_cidrs" {
  description = "CIDR blocks for the private application subnets"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

# CIDR blocks for isolated database subnets.
variable "database_subnet_cidrs" {
  description = "CIDR blocks for the isolated database subnets"
  type        = list(string)
  default     = ["10.0.31.0/24", "10.0.32.0/24"]
}
