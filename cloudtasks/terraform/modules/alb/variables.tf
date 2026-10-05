variable "sg_alb_id" {}
variable "vpc_id" {}
variable "public_subnets" {}

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