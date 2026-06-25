variable "name_prefix" {
  type = string
}

variable "secret_arn" {
  type        = string
  description = "Secrets Manager ARN the execution role is allowed to read."
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "ECR repo ARNs the execution role is allowed to pull from."
}
