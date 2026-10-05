variable "lb_dns_name" {}

variable "frontend_dist_path" {}

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