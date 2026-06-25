# Dev: optimized for cost and fast teardown.
environment = "dev"

# Networking — one shared NAT gateway (single point of failure, but ~half the cost).
az_count           = 2
single_nat_gateway = true

# RDS — smallest burstable instance, single-AZ (no standby).
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_multi_az          = false

# ECS — one task per service is enough to demo.
service_desired_count = 1
task_cpu              = "256"
task_memory           = "512"

# No TLS cert in dev (HTTP only).
acm_certificate_arn = ""
