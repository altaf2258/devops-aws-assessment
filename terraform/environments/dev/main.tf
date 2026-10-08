terraform {
  backend "s3" {
    bucket  = "devops-aws-assessment-terraform-state"
    key     = "dev/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "security_groups" {
  source      = "../../modules/security-groups"
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
}

module "s3" {
  source      = "../../modules/s3"
  name_prefix = local.name_prefix
  tags        = local.tags
}

module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = local.name_prefix
  tags        = local.tags
}

module "secrets" {
  source      = "../../modules/secrets-manager"
  name_prefix = local.name_prefix
  db_host     = module.rds.endpoint
  tags        = local.tags
}

module "rds" {
  source             = "../../modules/rds"
  name_prefix        = local.name_prefix
  private_subnet_ids = module.vpc.private_db_subnet_ids
  rds_sg_id          = module.security_groups.rds_sg_id
  db_password        = module.secrets.db_password
  tags               = local.tags
}

module "iam" {
  source              = "../../modules/iam"
  name_prefix         = local.name_prefix
  secret_arn          = module.secrets.secret_arn
  app_bucket_arn      = module.s3.app_bucket_arn
  ecr_repository_arns = module.ecr.repository_arns
  region              = var.aws_region
  tags                = local.tags
}

module "github_oidc" {
  source              = "../../modules/github-oidc"
  name_prefix         = local.name_prefix
  github_repo         = var.github_repo
  ecr_repository_arns = module.ecr.repository_arns
  app_bucket_arn      = module.s3.app_bucket_arn
}

module "alb" {
  source            = "../../modules/alb"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  certificate_arn   = var.certificate_arn
  logs_bucket_name  = module.s3.logs_bucket_name
  logs_prefix       = module.s3.logs_prefix
  tags              = local.tags

  depends_on = [module.s3]
}

module "asg" {
  source                = "../../modules/asg"
  name_prefix           = local.name_prefix
  region                = var.aws_region
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  app_sg_id             = module.security_groups.app_sg_id
  instance_profile_name = module.iam.instance_profile_name
  secret_name           = module.secrets.secret_name
  frontend_tg_arn       = module.alb.frontend_target_group_arn
  backend_tg_arn        = module.alb.backend_target_group_arn
  app_bucket_name       = module.s3.app_bucket_name
  tags                  = local.tags

  depends_on = [module.rds]
}