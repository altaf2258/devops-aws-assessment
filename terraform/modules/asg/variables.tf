variable "name_prefix" { type = string }
variable "region" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_sg_id" { type = string }
variable "instance_profile_name" { type = string }
variable "secret_name" { type = string }
variable "frontend_tg_arn" { type = string }
variable "backend_tg_arn" { type = string }


variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 1
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "app_bucket_name" {
  type = string
}
