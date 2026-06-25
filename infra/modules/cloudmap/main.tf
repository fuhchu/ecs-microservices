resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "ecs-msvc.local"
  description = "Service discovery namespace for ${var.name_prefix}"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "this" {
  for_each = toset(var.services)

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
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
