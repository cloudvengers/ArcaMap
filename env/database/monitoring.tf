locals {                                                                                   # 이 모듈에서 공유할 로컬 값
  service_alarms = {                                                                       # 서비스별 지표 경보 기준
    "rds-cpu" = {                                                                          # RDS CPU 사용률 경보
      namespace           = "AWS/RDS"                                                      # CloudWatch 지표 네임스페이스
      metric_name         = "CPUUtilization"                                               # 감시하거나 수집할 지표 이름
      statistic           = "Average"                                                      # 경보 대상 지표의 집계 방식
      threshold           = 80                                                             # 경보를 발생시킬 임계값
      comparison_operator = "GreaterThanOrEqualToThreshold"                                # 측정값과 임계값의 비교 방식
      period              = 300                                                            # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 3                                                              # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                              # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                      # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { DBInstanceIdentifier = module.database.database.identifier } # 경보에서 감시할 지표 차원
    }                                                                                      # 설정 묶음 끝
    "rds-free-memory" = {                                                                  # RDS 가용 메모리 경보
      namespace           = "AWS/RDS"                                                      # CloudWatch 지표 네임스페이스
      metric_name         = "FreeableMemory"                                               # 감시하거나 수집할 지표 이름
      statistic           = "Minimum"                                                      # 경보 대상 지표의 집계 방식
      threshold           = 536870912                                                      # 경보를 발생시킬 임계값
      comparison_operator = "LessThanThreshold"                                            # 측정값과 임계값의 비교 방식
      period              = 300                                                            # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 3                                                              # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                              # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                      # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { DBInstanceIdentifier = module.database.database.identifier } # 경보에서 감시할 지표 차원
    }                                                                                      # 설정 묶음 끝
    "rds-free-storage" = {                                                                 # RDS 가용 저장 공간 경보
      namespace           = "AWS/RDS"                                                      # CloudWatch 지표 네임스페이스
      metric_name         = "FreeStorageSpace"                                             # 감시하거나 수집할 지표 이름
      statistic           = "Minimum"                                                      # 경보 대상 지표의 집계 방식
      threshold           = 5368709120                                                     # 경보를 발생시킬 임계값
      comparison_operator = "LessThanThreshold"                                            # 측정값과 임계값의 비교 방식
      period              = 300                                                            # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 1                                                              # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 1                                                              # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                      # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { DBInstanceIdentifier = module.database.database.identifier } # 경보에서 감시할 지표 차원
    }                                                                                      # 설정 묶음 끝
  }                                                                                        # 설정 묶음 끝
}                                                                                          # 설정 묶음 끝

module "log_groups" {                                                # 서비스 로그 그룹 모듈 연결
  for_each = {                                                       # 대상 항목별로 블록 반복
    rds_postgresql = "/aws/rds/instance/arcamap-postgres/postgresql" # PostgreSQL 로그 그룹 이름
    rds_upgrade    = "/aws/rds/instance/arcamap-postgres/upgrade"    # PostgreSQL 업그레이드 로그 그룹 이름
  }                                                                  # 설정 묶음 끝
  source = "../../modules/cloudwatch-log-group"                      # 로컬 하위 모듈 경로

  name               = each.value             # AWS 리소스·규칙·작업 이름
  log_retention_days = var.log_retention_days # 로그 보존 기간(일)
}                                             # 설정 묶음 끝

module "service_alarms" {                     # 서비스 지표 경보 모듈 연결
  for_each = local.service_alarms             # 대상 항목별로 블록 반복
  source   = "../../modules/cloudwatch-alarm" # 로컬 하위 모듈 경로

  name  = "arcamap-${each.key}" # AWS 리소스·규칙·작업 이름
  alarm = each.value            # 서비스별 지표 경보 설정 전달
}                               # 설정 묶음 끝

module "db_connections" {                         # DB 연결 수 경보 모듈 연결
  count  = var.db_max_connections == null ? 0 : 1 # 조건에 따른 블록 생성 개수
  source = "../../modules/cloudwatch-alarm"       # 로컬 하위 모듈 경로

  name = "arcamap-rds-database-connections"                                                  # AWS 리소스·규칙·작업 이름
  alarm = {                                                                                  # 서비스별 지표 경보 설정 전달
    description         = "RDS PostgreSQL의 1분 평균 클라이언트 연결 수가 최대 연결 수의 80% 이상인 상태가 3회 연속 지속됨" # 리소스·경보의 용도 설명
    namespace           = "AWS/RDS"                                                          # CloudWatch 지표 네임스페이스
    metric_name         = "DatabaseConnections"                                              # 감시하거나 수집할 지표 이름
    unit                = "Count"                                                            # 지표 측정 단위
    statistic           = "Average"                                                          # 경보 대상 지표의 집계 방식
    threshold           = coalesce(var.db_max_connections, 0) * 0.8                          # 경보를 발생시킬 임계값
    comparison_operator = "GreaterThanOrEqualToThreshold"                                    # 측정값과 임계값의 비교 방식
    period              = 60                                                                 # 지표 집계·경보 평가 주기(초)
    datapoints_to_alarm = 3                                                                  # 경보에 필요한 임계값 위반 구간 수
    evaluation_periods  = 3                                                                  # 경보를 평가할 최근 구간 수
    treat_missing_data  = "missing"                                                          # 지표가 없을 때 경보 상태 판단 방식
    dimensions          = { DBInstanceIdentifier = module.database.database.identifier }     # 경보에서 감시할 지표 차원
  }                                                                                          # 설정 묶음 끝
}                                                                                            # 설정 묶음 끝
