data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}




module "alb" {
  source         = "./modules/alb"
  sg_alb_id      = module.security.sg_alb_id
  vpc_id         = module.network.vpc_id
  public_subnets = module.network.public_subnets
  environment    = var.environment
  name_prefix    = local.name_prefix
  common_tags    = local.common_tags

}


module "database" {
  source      = "./modules/database"
  db_password = var.db_password
  db_subnets  = module.network.db_subnets
  sg_db_id    = module.security.sg_db_id
  environment = var.environment
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "ecs" {
  source                    = "./modules/ecs"
  db_password               = var.db_password
  sg_app_id                 = module.security.sg_app_id
  postgres_instance         = module.database.db_instance
  postgres_instance_address = module.database.db_instance_address
  subnets_app               = module.network.app_subnets
  lb_target_group_arn       = module.alb.target_group_arn
  aws_lb_listener_http      = module.alb.lb_listener_http
  environment               = var.environment
  name_prefix               = local.name_prefix
  common_tags               = local.common_tags
}


module "frontend" {
  source             = "./modules/frontend"
  lb_dns_name        = module.alb.lb_dns_name
  frontend_dist_path = "${path.root}/../frontend/dist"
  environment        = var.environment
  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
}

module "network" {
  source      = "./modules/network"
  environment = var.environment
  common_tags = local.common_tags
  name_prefix = local.name_prefix
  azs         = local.azs
}

module "security" {
  source      = "./modules/security"
  vpc_id      = module.network.vpc_id
  environment = var.environment
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}


module "monitoring" {
  source                      = "./modules/monitoring"
  name_prefix                 = local.name_prefix
  common_tags                 = local.common_tags
  ecs_cluster_name            = module.ecs.cluster_name
  ecs_service_name            = module.ecs.service_name
  alb_arn_suffix              = module.alb.lb_arn_suffix
  alb_target_group_arn_suffix = module.alb.target_group_arn_suffix
}# Infracost PR test
