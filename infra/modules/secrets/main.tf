resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}-db-credentials"
  description             = "RDS credentials + connection string for ${var.environment}"
  recovery_window_in_days = 0 # allow immediate delete/recreate during dev teardown
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username     = var.db_username
    password     = var.db_password
    host         = var.db_host
    port         = var.db_port
    dbname       = var.db_name
    database_url = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_name}"
  })
}
