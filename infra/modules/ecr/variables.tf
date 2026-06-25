variable "services" {
  type        = list(string)
  description = "Service names — one ECR repository is created per entry."
}
