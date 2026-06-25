# Private DNS namespace for service-to-service discovery.
# Services register here and resolve each other by name, e.g. http://users.ecs-msvc.local:8000
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "ecs-msvc.local"
  description = "Service discovery for ${var.environment} microservices"
  vpc         = aws_vpc.main.id
}

# One discovery service per backend service.
# api-gateway is fronted by the ALB, so it does not strictly need a record,
# but registering all three keeps things uniform and allows internal calls.
resource "aws_service_discovery_service" "service" {
  for_each = toset(local.services)

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
