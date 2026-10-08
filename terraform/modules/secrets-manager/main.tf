resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+" # avoids / @ " and space, which RDS rejects
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/db-credentials"
  description             = "MySQL credentials for ${var.name_prefix}"
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
  })
}
