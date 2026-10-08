output "aws_region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "project_name" {
  value = var.project_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  value = module.vpc.private_db_subnet_ids
}
output "alb_dns_name" { value = module.alb.alb_dns_name }
output "rds_endpoint" { value = module.rds.endpoint }
output "asg_name" { value = module.asg.asg_name }
output "ecr_urls" { value = module.ecr.repository_urls }
output "app_bucket_name" { value = module.s3.app_bucket_name }
output "app_deploy_role_arn" { value = module.github_oidc.app_deploy_role_arn }
output "terraform_role_arn" { value = module.github_oidc.terraform_role_arn }
