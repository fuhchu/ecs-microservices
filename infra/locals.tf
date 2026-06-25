locals {
  name_prefix = "ecs-msvc-${var.environment}"

  # The three microservices. Used by ECR, Cloud Map, log groups, and ECS.
  services = ["api-gateway", "users", "items"]

  # Private DNS namespace name for service-to-service discovery.
  namespace = aws_service_discovery_private_dns_namespace.main.name # ecs-msvc.local

  # Per-service config: plain env vars, whether it needs the DB secret,
  # and whether it sits behind the public ALB.
  service_config = {
    "api-gateway" = {
      needs_db = false
      env = {
        USERS_SERVICE_URL = "http://users.${local.namespace}:8000"
        ITEMS_SERVICE_URL = "http://items.${local.namespace}:8000"
      }
      public = true
    }
    "users" = {
      needs_db = true
      env      = {}
      public   = false
    }
    "items" = {
      needs_db = true
      env = {
        USERS_SERVICE_URL = "http://users.${local.namespace}:8000"
      }
      public = false
    }
  }
}
