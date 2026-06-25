output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "rds_endpoint" {
  value = module.rds.address
}

output "db_secret_arn" {
  value = module.secrets.secret_arn
}

output "service_discovery_namespace" {
  value = module.cloudmap.namespace_name
}

output "github_actions_role_arn" {
  value = module.oidc.role_arn
}
