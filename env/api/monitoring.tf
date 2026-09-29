locals { # 이 모듈에서 공유할 로컬 값
  # ASG가 교체 경보를 참조하므로 경보 차원은 ASG 출력 대신 공통 입력 이름을 사용합니다.
  api_asg_name           = "arcamap-api"                                                                                                                                                           # ASG와 교체 경보가 공유할 이름
  cloudwatch_agent_start = "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json" # 이미지 빌드와 운영 EC2의 Agent 시작 명령

  # ponytail: API log path and format are not defined; add files.collect_list when the API is ready.
  cloudwatch_agent_config = {                                                # 메모리 지표와 시스템 로그 수집 설정
    metrics = {                                                              # 수집하거나 표시할 지표 목록
      namespace = "CWAgent"                                                  # CloudWatch 지표 네임스페이스
      append_dimensions = {                                                  # 수집 지표에 추가할 차원
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"                # 지표를 구분할 ASG 이름
        InstanceId           = "$${aws:InstanceId}"                          # 지표를 구분할 EC2 인스턴스 ID
      }                                                                      # 설정 묶음 끝
      aggregation_dimensions = [["AutoScalingGroupName"]]                    # 지표를 집계할 차원 조합
      metrics_collected = {                                                  # Agent가 수집할 지표 종류
        mem = {                                                              # 메모리 지표 수집 설정
          measurement                 = ["used_percent", "available"]        # 수집할 메모리 지표 항목
          metrics_collection_interval = 60                                   # Agent 지표 수집 주기(초)
        }                                                                    # 설정 묶음 끝
      }                                                                      # 설정 묶음 끝
    }                                                                        # 설정 묶음 끝
    logs = {                                                                 # CloudWatch Agent 로그 수집 설정
      logs_collected = {                                                     # 수집할 로그 소스 설정
        journald = {                                                         # systemd 저널 로그 수집 설정
          collect_list = [{                                                  # 수집할 시스템 로그 목록
            log_group_name  = module.log_groups["ec2_system"].log_group.name # 로그를 저장할 그룹 이름
            log_stream_name = "{instance_id}/system"                         # 인스턴스별 시스템 로그 스트림 이름
            priority        = "info"                                         # 수집할 journald 로그의 우선순위
          }]                                                                 # 설정 묶음 끝
        }                                                                    # 설정 묶음 끝
      }                                                                      # 설정 묶음 끝
    }                                                                        # 설정 묶음 끝
  }                                                                          # 설정 묶음 끝

  service_alarms = {                                                                                                           # 서비스별 지표 경보 기준
    "asg-inservice" = {                                                                                                        # 서비스 중인 ASG 인스턴스 수 경보
      namespace           = "AWS/AutoScaling"                                                                                  # CloudWatch 지표 네임스페이스
      metric_name         = "GroupInServiceInstances"                                                                          # 감시하거나 수집할 지표 이름
      statistic           = "Minimum"                                                                                          # 경보 대상 지표의 집계 방식
      threshold           = 2                                                                                                  # 경보를 발생시킬 임계값
      comparison_operator = "LessThanThreshold"                                                                                # 측정값과 임계값의 비교 방식
      period              = 60                                                                                                 # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 2                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                                                          # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { AutoScalingGroupName = local.api_asg_name }                                                      # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
    "ec2-status-check" = {                                                                                                     # EC2 상태 검사 실패 경보
      namespace           = "AWS/EC2"                                                                                          # CloudWatch 지표 네임스페이스
      metric_name         = "StatusCheckFailed"                                                                                # 감시하거나 수집할 지표 이름
      statistic           = "Maximum"                                                                                          # 경보 대상 지표의 집계 방식
      threshold           = 1                                                                                                  # 경보를 발생시킬 임계값
      comparison_operator = "GreaterThanOrEqualToThreshold"                                                                    # 측정값과 임계값의 비교 방식
      period              = 60                                                                                                 # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 2                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                                                          # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { AutoScalingGroupName = local.api_asg_name }                                                      # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
    "ec2-cpu" = {                                                                                                              # API EC2 CPU 사용률 경보
      namespace           = "AWS/EC2"                                                                                          # CloudWatch 지표 네임스페이스
      metric_name         = "CPUUtilization"                                                                                   # 감시하거나 수집할 지표 이름
      statistic           = "Average"                                                                                          # 경보 대상 지표의 집계 방식
      threshold           = 80                                                                                                 # 경보를 발생시킬 임계값
      comparison_operator = "GreaterThanOrEqualToThreshold"                                                                    # 측정값과 임계값의 비교 방식
      period              = 300                                                                                                # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 3                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                                                          # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { AutoScalingGroupName = local.api_asg_name }                                                      # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
    "ec2-memory" = {                                                                                                           # API EC2 메모리 사용률 경보
      namespace           = "CWAgent"                                                                                          # CloudWatch 지표 네임스페이스
      metric_name         = "mem_used_percent"                                                                                 # 감시하거나 수집할 지표 이름
      statistic           = "Average"                                                                                          # 경보 대상 지표의 집계 방식
      threshold           = 80                                                                                                 # 경보를 발생시킬 임계값
      comparison_operator = "GreaterThanOrEqualToThreshold"                                                                    # 측정값과 임계값의 비교 방식
      period              = 300                                                                                                # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 3                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                                                          # 지표가 없을 때 경보 상태 판단 방식
      unit                = "Percent"                                                                                          # 지표 측정 단위
      description         = "ASG 평균 메모리 사용률이 80% 이상인 5분 구간이 3회 연속 발생하면 경보."                                                    # 리소스·경보의 용도 설명
      dimensions          = { AutoScalingGroupName = local.api_asg_name }                                                      # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
    "alb-healthy-hosts" = {                                                                                                    # 정상 API 대상 수 경보
      namespace           = "AWS/ApplicationELB"                                                                               # CloudWatch 지표 네임스페이스
      metric_name         = "HealthyHostCount"                                                                                 # 감시하거나 수집할 지표 이름
      statistic           = "Minimum"                                                                                          # 경보 대상 지표의 집계 방식
      threshold           = 2                                                                                                  # 경보를 발생시킬 임계값
      comparison_operator = "LessThanThreshold"                                                                                # 측정값과 임계값의 비교 방식
      period              = 60                                                                                                 # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 2                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 3                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "missing"                                                                                          # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { LoadBalancer = module.alb.alb.arn_suffix, TargetGroup = module.alb.alb.target_group_arn_suffix } # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
    "alb-5xx" = {                                                                                                              # ALB 자체 HTTP 5xx 경보
      namespace           = "AWS/ApplicationELB"                                                                               # CloudWatch 지표 네임스페이스
      metric_name         = "HTTPCode_ELB_5XX_Count"                                                                           # 감시하거나 수집할 지표 이름
      statistic           = "Sum"                                                                                              # 경보 대상 지표의 집계 방식
      threshold           = 5                                                                                                  # 경보를 발생시킬 임계값
      comparison_operator = "GreaterThanOrEqualToThreshold"                                                                    # 측정값과 임계값의 비교 방식
      period              = 300                                                                                                # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 1                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 1                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "notBreaching"                                                                                     # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { LoadBalancer = module.alb.alb.arn_suffix }                                                       # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
    "api-5xx" = {                                                                                                              # API 대상 HTTP 5xx 경보
      namespace           = "AWS/ApplicationELB"                                                                               # CloudWatch 지표 네임스페이스
      metric_name         = "HTTPCode_Target_5XX_Count"                                                                        # 감시하거나 수집할 지표 이름
      statistic           = "Sum"                                                                                              # 경보 대상 지표의 집계 방식
      threshold           = 5                                                                                                  # 경보를 발생시킬 임계값
      comparison_operator = "GreaterThanOrEqualToThreshold"                                                                    # 측정값과 임계값의 비교 방식
      period              = 300                                                                                                # 지표 집계·경보 평가 주기(초)
      datapoints_to_alarm = 1                                                                                                  # 경보에 필요한 임계값 위반 구간 수
      evaluation_periods  = 1                                                                                                  # 경보를 평가할 최근 구간 수
      treat_missing_data  = "notBreaching"                                                                                     # 지표가 없을 때 경보 상태 판단 방식
      dimensions          = { LoadBalancer = module.alb.alb.arn_suffix, TargetGroup = module.alb.alb.target_group_arn_suffix } # 경보에서 감시할 지표 차원
    }                                                                                                                          # 설정 묶음 끝
  }                                                                                                                            # 설정 묶음 끝
}                                                                                                                              # 설정 묶음 끝

module "log_groups" {                                # 서비스 로그 그룹 모듈 연결
  for_each = {                                       # 대상 항목별로 블록 반복
    ec2_system   = "/arcamap/ec2/system"             # EC2 시스템 로그 그룹 이름
    api          = "/arcamap/api/application"        # API 항목 설정
    alb          = "/aws/vendedlogs/elb/arcamap-api" # ALB 로그 그룹 조회·연결 정보
    imagebuilder = "/aws/imagebuilder/arcamap-api"   # Image Builder 로그 그룹 이름
  }                                                  # 설정 묶음 끝
  source = "../../modules/cloudwatch-log-group"      # 로컬 하위 모듈 경로

  name               = each.value             # AWS 리소스·규칙·작업 이름
  log_retention_days = var.log_retention_days # 로그 보존 기간(일)
}                                             # 설정 묶음 끝

module "service_alarms" {                     # 서비스 지표 경보 모듈 연결
  for_each = local.service_alarms             # 대상 항목별로 블록 반복
  source   = "../../modules/cloudwatch-alarm" # 로컬 하위 모듈 경로

  name  = "arcamap-${each.key}" # AWS 리소스·규칙·작업 이름
  alarm = each.value            # 서비스별 지표 경보 설정 전달
}                               # 설정 묶음 끝
