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
module "eks" {
  source = "../../modules/eks"

  cluster_name       = "capston-1-dev"
  kubernetes_version = "1.36"

  private_subnet_ids = module.networking.private_subnet_ids

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_instance_types = ["t3.small"]
  node_min_size       = 2
  node_desired_size   = 2
  node_max_size       = 3
}
