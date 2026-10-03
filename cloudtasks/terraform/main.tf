data "aws_availability_zones" "available" {
  state = "available"
}

module "alb" {
  source = "./modules/alb"
  sg_alb_id = module.security.sg_alb_id
  vpc_id = module.network.vpc_id
  public_subnets = module.network.public_subnets
}


module "database" {
  source = "./modules/database"
  db_password = var.db_password
  db_subnets = module.network.db_subnets
  sg_db_id = module.security.sg_db_id
}

module "ecs" {
  source = "./modules/ecs"
  db_password = var.db_password
  sg_app_id = module.security.sg_app_id
  postgres_instance = module.database.db_instance
  postgres_instance_address = module.database.db_instance_address
  subnets_app = module.network.app_subnets  
  lb_target_group_arn = module.alb.target_group_arn
  aws_lb_listener_http = module.alb.lb_listener_http
}


module "frontend" {
  source = "./modules/frontend"
  lb_dns_name = module.alb.lb_dns_name
  frontend_dist_path = "${path.root}/../frontend/dist"
  
}

module "network" {
  source = "./modules/network"
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}



