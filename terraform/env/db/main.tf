data "aws_vpc" "main" {
  tags = { Name = "arcamap-vpc" }
}

data "aws_subnet" "database" {
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"])

  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.key
  tags              = { Name = "arcamap-database-${each.key}" }
}

data "aws_security_group" "database" {
  name   = "arcamap-database"
  vpc_id = data.aws_vpc.main.id
}

locals {
  db_connection_threshold = coalesce(var.db_max_connections, 0) * 0.8

  service_alarms = {
    "rds-cpu" = {
      namespace           = "AWS/RDS"
      metric_name         = "CPUUtilization"
      statistic           = "Average"
      threshold           = 80
      comparison_operator = "GreaterThanOrEqualToThreshold"
      period              = 300
      datapoints_to_alarm = 3
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions          = { DBInstanceIdentifier = module.database.database.identifier }
    }
    "rds-free-memory" = {
      namespace           = "AWS/RDS"
      metric_name         = "FreeableMemory"
      statistic           = "Minimum"
      threshold           = 536870912
      comparison_operator = "LessThanThreshold"
      period              = 300
      datapoints_to_alarm = 3
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions          = { DBInstanceIdentifier = module.database.database.identifier }
    }
    "rds-free-storage" = {
      namespace           = "AWS/RDS"
      metric_name         = "FreeStorageSpace"
      statistic           = "Minimum"
      threshold           = 5368709120
      comparison_operator = "LessThanThreshold"
      period              = 300
      datapoints_to_alarm = 1
      evaluation_periods  = 1
      treat_missing_data  = "missing"
      dimensions          = { DBInstanceIdentifier = module.database.database.identifier }
    }
  }
}

module "log_groups" {
  for_each = {
    rds_postgresql = "/aws/rds/instance/arcamap-postgres/postgresql"
    rds_upgrade    = "/aws/rds/instance/arcamap-postgres/upgrade"
  }
  source = "../../modules/cloudwatch-log-group"

  name               = each.value
  log_retention_days = var.log_retention_days
}

module "database" {
  source = "../../modules/database"

  database_subnet_ids          = [for subnet in data.aws_subnet.database : subnet.id]
  database_security_group_id   = data.aws_security_group.database.id
  db_allocated_storage         = var.db_allocated_storage
  db_engine_version            = var.db_engine_version
  db_final_snapshot_identifier = var.db_final_snapshot_identifier
  db_instance_class            = var.db_instance_class
  db_max_allocated_storage     = var.db_max_allocated_storage
  db_password                  = var.db_password
  db_username                  = var.db_username

  # RDS의 자동 로그 내보내기보다 지정한 보존 기간의 로그 그룹을 먼저 생성합니다.
  depends_on = [module.log_groups]
}

module "service_alarms" {
  for_each = local.service_alarms
  source   = "../../modules/cloudwatch-alarm"

  name  = "arcamap-${each.key}"
  alarm = each.value
}

module "db_connections" {
  count  = var.db_max_connections == null ? 0 : 1
  source = "../../modules/cloudwatch-alarm"

  name = "arcamap-rds-database-connections"
  alarm = {
    description         = "RDS PostgreSQL의 1분 평균 클라이언트 연결 수가 최대 연결 수의 80% 이상인 상태가 3회 연속 지속됨"
    namespace           = "AWS/RDS"
    metric_name         = "DatabaseConnections"
    unit                = "Count"
    statistic           = "Average"
    threshold           = local.db_connection_threshold
    comparison_operator = "GreaterThanOrEqualToThreshold"
    period              = 60
    datapoints_to_alarm = 3
    evaluation_periods  = 3
    treat_missing_data  = "missing"
    dimensions          = { DBInstanceIdentifier = module.database.database.identifier }
  }
}
