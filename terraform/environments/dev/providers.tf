provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-aws-assessment"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
