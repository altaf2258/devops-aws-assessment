variable "name_prefix" { type = string }

variable "secret_arn" {
  type        = string
  description = "ARN of the DB credentials secret the instances may read"
}

variable "app_bucket_arn" {
  type        = string
  description = "ARN of the application S3 bucket"
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "ecr_repository_arns" { type = list(string) }
variable "region" { type = string }
