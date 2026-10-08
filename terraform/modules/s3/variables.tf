variable "name_prefix" { type = string }

variable "force_destroy" {
  type    = bool
  default = true # fine for an assessment; set false in prod
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
