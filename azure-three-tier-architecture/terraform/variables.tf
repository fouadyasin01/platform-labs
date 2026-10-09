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
  default = "Spain Central"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
  default   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJI2dBSJicQ5hbW2kWCvYjDAp0dBh3oARQc1wRgLrqJ fouad@platform"
}

variable "database_password" {
  type      = string
  sensitive = true
  default   = "db_password" # Replace with a secure password in production
}
