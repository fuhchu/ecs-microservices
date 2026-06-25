variable "region" {
  type    = string
  default = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (dev, prod)"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Number of AZs to span"
  default     = 2
}

variable "single_nat_gateway" {
  type        = bool
  description = "If true, one shared NAT gateway (cheap, dev). If false, one per AZ (HA, prod)."
  default     = true
}

# --- RDS ---

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type        = bool
  description = "Multi-AZ RDS for failover (prod)"
  default     = false
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

# --- ALB / TLS ---

variable "acm_certificate_arn" {
  type        = string
  description = "ACM cert ARN for HTTPS. When set, enables a 443 listener and redirects HTTP->HTTPS. Empty = HTTP only."
  default     = ""
}

# --- ECS ---

variable "service_desired_count" {
  type        = number
  description = "Number of Fargate tasks per service"
  default     = 1
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}
