variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_tasks_sg_id" {
  type = string
}

variable "task_execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "ecr_repository_urls" {
  type = map(string)
}

variable "secret_arn" {
  type = string
}

variable "namespace_name" {
  type        = string
  description = "Cloud Map private DNS namespace (e.g. ecs-msvc.local)."
}

variable "service_discovery_arns" {
  type        = map(string)
  description = "Map of service name -> Cloud Map service ARN."
}

variable "alb_target_group_arn" {
  type        = string
  description = "ALB target group ARN — attached only to the public-facing service."
}

variable "service_desired_count" {
  type    = number
  default = 1
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "service_config" {
  type = map(object({
    needs_db = bool
    env      = map(string)
    public   = bool
  }))
  description = "Per-service configuration map passed from the environment root."
}
