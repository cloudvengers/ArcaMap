resource "aws_autoscaling_policy" "api_cpu" {             # Auto Scaling 정책 정의
  name                   = "arcamap-api-cpu"              # AWS 리소스·규칙·작업 이름
  autoscaling_group_name = aws_autoscaling_group.api.name # 정책을 적용할 Auto Scaling 그룹 이름
  policy_type            = "TargetTrackingScaling"        # Auto Scaling 정책 유형

  target_tracking_configuration {         # 목표 추적 확장 설정
    target_value     = var.asg_cpu_target # 목표 추적 확장의 지표 목표값
    disable_scale_in = false              # 목표 추적 정책의 축소 차단 여부

    predefined_metric_specification {                     # AWS 기본 지표 선택
      predefined_metric_type = "ASGAverageCPUUtilization" # 확장 기준으로 사용할 AWS 기본 지표
    }                                                     # 설정 묶음 끝
  }                                                       # 설정 묶음 끝
}                                                         # 설정 묶음 끝

resource "aws_autoscaling_policy" "api_memory" {          # Auto Scaling 정책 정의
  name                   = "arcamap-api-memory"           # AWS 리소스·규칙·작업 이름
  autoscaling_group_name = aws_autoscaling_group.api.name # 정책을 적용할 Auto Scaling 그룹 이름
  policy_type            = "TargetTrackingScaling"        # Auto Scaling 정책 유형

  target_tracking_configuration {            # 목표 추적 확장 설정
    target_value     = var.asg_memory_target # 목표 추적 확장의 지표 목표값
    disable_scale_in = false                 # 목표 추적 정책의 축소 차단 여부

    customized_metric_specification {  # Agent 수집 지표 선택
      namespace   = "CWAgent"          # CloudWatch 지표 네임스페이스
      metric_name = "mem_used_percent" # 감시하거나 수집할 지표 이름
      statistic   = "Average"          # 경보 대상 지표의 집계 방식
      unit        = "Percent"          # 지표 측정 단위

      metric_dimension {                       # 확장 지표의 ASG 차원
        name  = "AutoScalingGroupName"         # AWS 리소스·규칙·작업 이름
        value = aws_autoscaling_group.api.name # 확장 지표의 ASG 차원 값
      }                                        # 설정 묶음 끝
    }                                          # 설정 묶음 끝
  }                                            # 설정 묶음 끝
}                                              # 설정 묶음 끝
