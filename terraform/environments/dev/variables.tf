variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devops-assessment"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

# this is from vpc
variable "availability_zones" {
  description = "Availability zones for the environment"
  type        = list(string)

  default = [
    "ap-south-1a",
    "ap-south-1b"
  ]
}
variable "github_repo" {
  description = "GitHub repo in owner/repo format"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener"
  type        = string
}