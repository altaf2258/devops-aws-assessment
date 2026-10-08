variable "name_prefix" { type = string }

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_name" {
  type    = string
  default = "assessment"
}

# Filled from the RDS module output
variable "db_host" { type = string }

variable "db_port" {
  type    = number
  default = 3306
}

variable "recovery_window_in_days" {
  type    = number
  default = 0 # 0 = delete immediately, easier for an assessment; use 7-30 in prod
}

variable "tags" {
  type    = map(string)
  default = {}
}
