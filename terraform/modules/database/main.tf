resource "aws_db_subnet_group" "database" {
  name       = "arcamap-database"
  subnet_ids = var.database_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier          = "arcamap-postgres"
  db_name             = "arcamap"
  engine              = "postgres"
  engine_version      = var.db_engine_version
  instance_class      = var.db_instance_class
  username            = var.db_username
  password_wo         = var.db_password
  password_wo_version = 1

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false
  network_type           = "IPV4"
  port                   = 5432

  storage_type          = "gp3"
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_encrypted     = true

  auto_minor_version_upgrade  = false
  allow_major_version_upgrade = false
  backup_retention_period     = 3
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = var.db_final_snapshot_identifier

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

}
