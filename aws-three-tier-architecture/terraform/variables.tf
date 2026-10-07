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

# EC2 instance type for the Nginx web tier.
variable "web_instance_type" {
  description = "EC2 instance type for the web tier"
  type        = string
  default     = "t3.micro"
}

# EC2 instance type for the Node.js application tier.
variable "app_instance_type" {
  description = "EC2 instance type for the application tier"
  type        = string
  default     = "t3.micro"
}

# PostgreSQL engine version for the application database.
variable "database_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

# RDS instance class for the application database.
variable "database_instance_class" {
  description = "RDS instance class for the database"
  type        = string
  default     = "db.t3.micro"
}

/*
# Initial application database name.
variable "database_name" {
  description = "Name of the application database"
  type        = string
  default     = "appdb"
}

# Master username for PostgreSQL.
variable "database_username" {
  description = "Master username for the PostgreSQL database"
  type        = string
  default     = "appadmin"
}
*/
# Master password supplied securely through Terraform variables.
variable "database_password" {
  description = "Master password for the PostgreSQL database"
  type        = string
  sensitive   = true
}
