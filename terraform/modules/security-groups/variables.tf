variable "name_prefix" { type = string }
variable "vpc_id" { type = string }

variable "app_ports" {
  type        = list(number)
  description = "Ports the ALB can reach on app instances"
  default     = [80, 3000] # 80 = frontend (nginx), 3000 = backend API
}

variable "tags" {
  type    = map(string)
  default = {}
}