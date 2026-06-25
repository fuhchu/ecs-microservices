output "namespace_name" {
  value = aws_service_discovery_private_dns_namespace.this.name
}

output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.this.id
}

output "service_arns" {
  value = { for k, svc in aws_service_discovery_service.this : k => svc.arn }
}
