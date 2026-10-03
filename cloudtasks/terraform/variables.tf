variable "aws_region" {
  description = "AWS region where the infrastructure will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Password for the CloudTasks PostgreSQL database."
  type        = string
  sensitive   = true
  default     = "cloudtasks_db_password"
}

variable "environment" {
  description = "The deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}


variable "project_name" {
  description = "The project name for tagging and identification."
  type        = string
}