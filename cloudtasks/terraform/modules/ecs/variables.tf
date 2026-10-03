variable "db_password" {
  description = "Password for the CloudTasks PostgreSQL database."
  type        = string
  sensitive   = true
}

variable "sg_app_id" {
  description = "Security group ID for the CloudTasks ECS application."
  type        = string
}

variable "postgres_instance" {
  description = "Address of the CloudTasks PostgreSQL instance."
}

variable "postgres_instance_address" {
  description = "Address of the CloudTasks PostgreSQL instance."
  type        = string
}

variable "subnets_app" {

}

variable "lb_target_group_arn" {
  description = "ARN of the load balancer target group for the ECS service."
  type        = string
}

variable "aws_lb_listener_http" {

}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for naming resources."
  type        = string
}
variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}


/*
variable "azs" {
  description = "List of availability zones to use for ECS tasks."
  type        = list(string)
}
*/