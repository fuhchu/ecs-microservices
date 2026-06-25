variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "services" {
  type        = list(string)
  description = "Service names — one Cloud Map service record is created per entry."
}
