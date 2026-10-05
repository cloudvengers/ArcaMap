resource "aws_autoscaling_group" "api" {                                          # Auto Scaling 그룹 정의
  name                      = var.asg_name                                        # AWS 리소스·규칙·작업 이름
  min_size                  = 1                                                   # ASG 최소 인스턴스 수
  max_size                  = var.asg_max_size                                    # ASG 최대 인스턴스 수
  health_check_type         = var.asg_health_check_type                           # ASG 상태 검사 기준
  health_check_grace_period = 300                                                 # EC2 시작 후 상태 검사 유예 시간(초)
  default_instance_warmup   = 300                                                 # 확장 후 지표 집계까지의 준비 시간(초)
  vpc_zone_identifier       = var.api_subnet_ids                                  # ASG 인스턴스를 배치할 서브넷 ID 목록
  target_group_arns         = [var.target_group_arn]                              # ASG 인스턴스를 등록할 대상 그룹 ARN 목록
  enabled_metrics           = ["GroupInServiceInstances", "GroupDesiredCapacity"] # ASG가 수집할 지표 종류
  metrics_granularity       = "1Minute"                                           # ASG 지표 수집 주기

  launch_template {                                  # ASG 시작 템플릿 연결
    id      = aws_launch_template.api.id             # ASG가 사용할 시작 템플릿 ID
    version = aws_launch_template.api.latest_version # 시작 템플릿의 최신 버전 번호
  }                                                  # 설정 묶음 끝

  instance_refresh {     # ASG 인스턴스 교체 설정
    strategy = "Rolling" # ASG 인스턴스 교체 방식

    preferences {                   # 인스턴스 교체 중 용량·롤백 기준
      min_healthy_percentage = 100  # 인스턴스 교체 중 유지할 최소 정상 비율(%)
      max_healthy_percentage = 200  # 인스턴스 교체 중 허용할 최대 용량 비율(%)
      instance_warmup        = 300  # 교체 인스턴스 준비 시간(초)
      skip_matching          = true # 새 설정과 같은 기존 인스턴스 교체 생략 여부
      auto_rollback          = true # 인스턴스 교체 실패 시 자동 롤백 여부

      alarm_specification {                       # 교체 실패 감시 경보 연결
        alarms = var.instance_refresh_alarm_names # 감시할 경보 목록
      }                                           # 설정 묶음 끝
    }                                             # 설정 묶음 끝
  }                                               # 설정 묶음 끝

} # 설정 묶음 끝
