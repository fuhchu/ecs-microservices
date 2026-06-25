# Prod: optimized for high availability and resilience.
environment = "prod"

# Networking — one NAT gateway per AZ (no cross-AZ SPOF, no cross-AZ data charges).
az_count           = 2
single_nat_gateway = false

# RDS — larger instance with a Multi-AZ standby for automatic failover.
db_instance_class    = "db.t3.small"
db_allocated_storage = 50
db_multi_az          = true

# ECS — two tasks per service across AZs for redundancy.
service_desired_count = 2
task_cpu              = "512"
task_memory           = "1024"

# TLS: set to a real ACM cert ARN to enable HTTPS + HTTP->HTTPS redirect.
# acm_certificate_arn = "arn:aws:acm:us-west-2:445481011516:certificate/xxxxxxxx"
acm_certificate_arn = ""
