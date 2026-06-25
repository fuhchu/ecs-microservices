variable "name_prefix" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in owner/repo format (e.g. fuhchu/ecs-microservices)."
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "ECR repo ARNs the GitHub Actions role is allowed to push to."
}

variable "task_execution_role_arn" {
  type        = string
  description = "ARN the GitHub Actions role is allowed to PassRole to ECS."
}

variable "task_role_arn" {
  type        = string
  description = "ARN the GitHub Actions role is allowed to PassRole to ECS."
}
