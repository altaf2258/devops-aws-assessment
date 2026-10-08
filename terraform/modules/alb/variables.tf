variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the HTTPS listener"
}

variable "logs_bucket_name" { type = string }
variable "logs_prefix" {
  type    = string
  default = "alb"
}

variable "frontend_port" {
  type    = number
  default = 80
}

variable "backend_port" {
  type    = number
  default = 3000
}

variable "backend_health_path" {
  type    = string
  default = "/health"
}

variable "tags" {
  type    = map(string)
  default = {}
}
