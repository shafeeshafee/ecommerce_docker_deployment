# main.tf

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
  region = var.aws_region
}

module "network" {
  source = "./modules/network"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = values(var.public_subnet_cidrs)
  public_subnet_azs    = keys(var.public_subnet_cidrs)
  private_subnet_cidrs = values(var.private_subnet_cidrs)
  private_subnet_azs   = keys(var.private_subnet_cidrs)
}

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id = module.network.vpc_id
}

module "database" {
  source = "./modules/database"

  private_subnet_ids    = module.network.private_subnet_ids
  db_instance_class     = var.db_instance_class
  db_allocated_storage  = var.db_allocated_storage
  db_username           = var.db_username
  db_password           = var.db_password
  rds_security_group_id = module.security_groups.rds_sg_id
}

module "compute" {
  source = "./modules/compute"

  public_subnet_ids         = module.network.public_subnet_ids
  private_subnet_ids        = module.network.private_subnet_ids
  bastion_security_group_id = module.security_groups.bastion_sg_id
  app_security_group_id     = module.security_groups.app_sg_id
  key_name                  = var.key_name
  instance_type_bastion     = var.instance_type_bastion
  instance_type_app         = var.instance_type_app
  rds_address               = module.database.rds_address
  db_username               = var.db_username
  db_password               = var.db_password
  dockerhub_username        = var.dockerhub_username
  dockerhub_password        = var.dockerhub_password
  deploy_script_path        = "${path.module}/deploy.sh"
  compose_template_path     = "${path.module}/compose.yml"
}

module "load_balancer" {
  source = "./modules/load_balancer"

  alb_security_group_id = module.security_groups.alb_sg_id
  public_subnet_ids     = module.network.public_subnet_ids
  vpc_id                = module.network.vpc_id
  app_instance_ids      = module.compute.app_instance_ids
}

# Outputs are defined in outputs.tf
