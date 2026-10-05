variable "db_password" {
  description = "Password for the CloudTasks PostgreSQL database."
  type        = string
  sensitive   = true
}


variable "db_subnets" {}

variable "sg_db_id" {}

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