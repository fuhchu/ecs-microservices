variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM cert ARN. When set, enables HTTPS + HTTP->HTTPS redirect. Empty = HTTP only."
  default     = ""
}
