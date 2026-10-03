variable "db_password" {
  description = "Password for the CloudTasks PostgreSQL database."
  type        = string
  sensitive   = true
}


variable "db_subnets" {}

variable "sg_db_id" {}