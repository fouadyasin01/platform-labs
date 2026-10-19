data "aws_caller_identity" "current" {}

module "networking" {
  source = "../../modules/networking"

  project_name = "capston-1"
  vpc_cidr     = "10.20.0.0/16"

  availability_zones = var.availability_zones

  public_subnet_cidrs = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]

  private_subnet_cidrs = [
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]
}