mock_provider "aws" {
  override_during = plan

  mock_data "aws_vpc" {
    defaults = { id = "vpc-00000000000000001" }
  }

  mock_data "aws_security_group" {
    defaults = { id = "sg-00000000000000003" }
  }

  override_data {
    target = data.aws_subnet.database["ap-northeast-2a"]
    values = { id = "subnet-00000000000000021" }
  }

  override_data {
    target = data.aws_subnet.database["ap-northeast-2c"]
    values = { id = "subnet-00000000000000022" }
  }
}

variables {
  db_allocated_storage         = 20
  db_max_allocated_storage     = 100
  db_engine_version            = "18.3"
  db_instance_class            = "db.t3.small"
  db_username                  = "testadmin"
  db_password                  = "Unit-test-only-123!"
  db_final_snapshot_identifier = "arcamap-test-final"
  db_max_connections           = null
  log_retention_days           = 30
}

run "initial_database" {
  command = plan

  assert {
    condition = (
      data.aws_vpc.main.tags["Name"] == "arcamap-vpc" &&
      data.aws_security_group.database.name == "arcamap-database" &&
      data.aws_security_group.database.vpc_id == data.aws_vpc.main.id &&
      toset(keys(data.aws_subnet.database)) == toset(["ap-northeast-2a", "ap-northeast-2c"]) &&
      alltrue([for az, subnet in data.aws_subnet.database :
        subnet.vpc_id == data.aws_vpc.main.id &&
        subnet.availability_zone == az &&
        subnet.tags["Name"] == "arcamap-database-${az}"
      ])
    )
    error_message = "DB는 app의 VPC 안에서 DB 보안 그룹과 역할·AZ별 DB 서브넷을 조회해야 합니다."
  }

  assert {
    condition = (
      length(module.db_connections) == 0 &&
      toset(keys(module.service_alarms)) == toset(["rds-cpu", "rds-free-memory", "rds-free-storage"]) &&
      toset(keys(output.log_groups)) == toset(["rds_postgresql", "rds_upgrade"]) &&
      output.database.identifier == "arcamap-postgres"
    )
    error_message = "db는 RDS·DB 로그 2개·기본 경보 3개를 소유하며 최대 연결 수 미입력 시 연결 수 경보를 만들지 않아야 합니다."
  }
}

run "database_limit_available" {
  command = plan

  variables {
    # 실제 운영값은 SHOW max_connections;로 조회합니다.
    db_max_connections = 100
  }

  assert {
    condition     = length(module.db_connections) == 1 && local.db_connection_threshold == 80
    error_message = "최대 연결 수 100을 입력하면 경보 1개와 80% 임계값을 구성해야 합니다."
  }
}

run "reject_invalid_database_limit" {
  command = plan

  variables {
    db_max_connections = 0
  }

  expect_failures = [var.db_max_connections]
}

run "database_private_and_protected" {
  command = plan

  module {
    source = "../../modules/database"
  }

  variables {
    database_subnet_ids        = ["subnet-00000000000000021", "subnet-00000000000000022"]
    database_security_group_id = "sg-00000000000000003"
  }

  assert {
    condition = (
      !aws_db_instance.postgres.publicly_accessible &&
      aws_db_instance.postgres.multi_az &&
      aws_db_instance.postgres.port == 5432 &&
      aws_db_instance.postgres.storage_encrypted &&
      aws_db_instance.postgres.deletion_protection &&
      !aws_db_instance.postgres.skip_final_snapshot &&
      aws_db_instance.postgres.password_wo_version == 1 &&
      toset(aws_db_instance.postgres.enabled_cloudwatch_logs_exports) == toset(["postgresql", "upgrade"]) &&
      aws_db_instance.postgres.vpc_security_group_ids == toset(["sg-00000000000000003"])
    )
    error_message = "RDS의 사설·Multi-AZ·암호화·삭제 보호·최종 스냅샷·write-only 비밀번호 설정을 유지해야 합니다."
  }
}
