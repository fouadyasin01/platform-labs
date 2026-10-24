variable "project_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  type = list(string)
}

variable "worker_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "desired_nodes" {
  type    = number
  default = 2
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}
