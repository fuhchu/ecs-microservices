variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "single_nat_gateway" {
  type        = bool
  description = "true = one shared NAT (dev/cost). false = one per AZ (prod/HA)."
  default     = true
}
