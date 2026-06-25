output "alb_dns_name" {
  description = "Public DNS of the ALB — entry point to the api-gateway"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_urls" {
  description = "ECR repo URLs per service (for docker push)"
  value       = { for k, repo in aws_ecr_repository.service : k => repo.repository_url }
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "rds_endpoint" {
  description = "RDS endpoint (private; reachable only from within the VPC)"
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the DB credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "service_discovery_namespace" {
  value = aws_service_discovery_private_dns_namespace.main.name
}
