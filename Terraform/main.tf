terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "./modules/network"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  key_name             = var.key_name
}

module "database" {
  source = "./modules/database"

  vpc_id               = module.network.vpc_id
  private_subnet_ids   = [module.network.private_subnet_ids["az1"], module.network.private_subnet_ids["az2"]]
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  rds_sg_id            = module.network.rds_sg_id
}

module "compute" {
  source = "./modules/compute"

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  bastion_sg_id         = module.network.bastion_sg_id
  app_sg_id             = module.network.app_sg_id
  alb_sg_id             = module.network.alb_sg_id
  rds_address           = module.database.rds_endpoint
  db_username           = var.db_username
  db_password           = var.db_password
  dockerhub_username    = var.dockerhub_username
  dockerhub_password    = var.dockerhub_password
  key_name              = var.key_name
  instance_type_bastion = var.instance_type_bastion
  instance_type_app     = var.instance_type_app
  nat_gateway_id        = module.network.nat_gateway_id
}


module "monitoring" {
  source   = "./modules/monitoring"
  key_name = var.key_name
  vpc_id   = module.network.vpc_id
  app_private_ips = [
    module.compute.app_az1_private_ip,
    module.compute.app_az2_private_ip
  ]

  depends_on = [module.compute]
}
