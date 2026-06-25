# Generate a strong DB password — never hardcoded, never in tfvars.
resource "random_password" "db" {
  length  = 24
  special = true
  # RDS disallows a few chars in the master password
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store the full set of DB connection details as one JSON secret.
# ECS will inject individual keys from this at container start.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name_prefix}-db-credentials"
  description             = "RDS credentials + connection string for ${var.environment}"
  recovery_window_in_days = 0 # allow immediate delete/recreate during dev teardown
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username     = var.db_username
    password     = random_password.db.result
    host         = aws_db_instance.main.address
    port         = aws_db_instance.main.port
    dbname       = var.db_name
    database_url = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
  })
}
