locals {
  name_prefix = "ecs-msvc-${var.environment}"
  services    = ["api-gateway", "users", "items"]

  service_config = {
    "api-gateway" = {
      needs_db = false
      env = {
        USERS_SERVICE_URL = "http://users.${module.cloudmap.namespace_name}:8000"
        ITEMS_SERVICE_URL = "http://items.${module.cloudmap.namespace_name}:8000"
      }
      public = true
    }
    "users" = {
      needs_db = true
      env      = {}
      public   = false
    }
    "items" = {
      needs_db = true
      env = {
        USERS_SERVICE_URL = "http://users.${module.cloudmap.namespace_name}:8000"
      }
      public = false
    }
  }
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "vpc" {
  source             = "../../modules/vpc"
  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

module "ecr" {
  source   = "../../modules/ecr"
  services = local.services
}

module "cloudmap" {
  source      = "../../modules/cloudmap"
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  services    = local.services
}

module "alb" {
  source              = "../../modules/alb"
  name_prefix         = local.name_prefix
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  acm_certificate_arn = var.acm_certificate_arn
}

module "rds" {
  source               = "../../modules/rds"
  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  ecs_tasks_sg_id      = module.vpc.ecs_tasks_sg_id
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_multi_az          = var.db_multi_az
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = random_password.db.result
}

module "secrets" {
  source      = "../../modules/secrets"
  name_prefix = local.name_prefix
  environment = var.environment
  db_username = var.db_username
  db_password = random_password.db.result
  db_host     = module.rds.address
  db_port     = module.rds.port
  db_name     = module.rds.db_name
}

module "iam" {
  source              = "../../modules/iam"
  name_prefix         = local.name_prefix
  secret_arn          = module.secrets.secret_arn
  ecr_repository_arns = values(module.ecr.repository_arns)
}

module "ecs" {
  source                  = "../../modules/ecs"
  name_prefix             = local.name_prefix
  region                  = var.region
  private_subnet_ids      = module.vpc.private_subnet_ids
  ecs_tasks_sg_id         = module.vpc.ecs_tasks_sg_id
  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn
  ecr_repository_urls     = module.ecr.repository_urls
  secret_arn              = module.secrets.secret_arn
  namespace_name          = module.cloudmap.namespace_name
  service_discovery_arns  = module.cloudmap.service_arns
  alb_target_group_arn    = module.alb.target_group_arn
  service_desired_count   = var.service_desired_count
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  service_config          = local.service_config
}

module "oidc" {
  source                  = "../../modules/oidc"
  name_prefix             = local.name_prefix
  github_repo             = "fuhchu/ecs-microservices"
  ecr_repository_arns     = values(module.ecr.repository_arns)
  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn
}
