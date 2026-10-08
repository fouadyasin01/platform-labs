variable "project_name" {
  type    = string
  default = "azure-three-tier"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "database_password" {
  type      = string
  sensitive = true
}
