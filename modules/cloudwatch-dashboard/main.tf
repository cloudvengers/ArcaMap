locals {                                                                                                                                                                                  # 이 모듈에서 공유할 로컬 값
  metric_panels = [                                                                                                                                                                       # 서비스 지표 패널 정의
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "ASG 인스턴스 수"                                                                                                                                                                # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.asg_name],                                                                                             # GroupInServiceInstances 지표와 대상 차원 표시
        ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.asg_name],                                                                                                # GroupDesiredCapacity 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "ASG 평균 CPU·메모리 사용률 (%)"                                                                                                                                                    # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name],                                                                                                              # CPUUtilization 지표와 대상 차원 표시
        ["CWAgent", "mem_used_percent", "AutoScalingGroupName", var.asg_name],                                                                                                            # mem_used_percent 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "EC2 인스턴스별 메모리 사용률 (%)"                                                                                                                                                     # 대시보드 패널 제목
      metrics = [[{                                                                                                                                                                       # 수집하거나 표시할 지표 목록
        expression = "SEARCH('{CWAgent,AutoScalingGroupName,InstanceId} MetricName=\"mem_used_percent\" AutoScalingGroupName=\"${var.asg_name}\"', 'Average', 300)"                       # 인스턴스별 지표를 찾는 CloudWatch 검색 식
        id         = "memory"                                                                                                                                                             # 호출자에게 전달할 리소스 ID
      }]]                                                                                                                                                                                 # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "ASG 평균 가용 메모리 (Bytes)"                                                                                                                                                     # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["CWAgent", "mem_available", "AutoScalingGroupName", var.asg_name],                                                                                                               # mem_available 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "ALB 정상 대상 수 (5분 최솟값)"                                                                                                                                                      # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Minimum" }],                                 # HealthyHostCount 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "ALB 요청 수 (5분 합계)"                                                                                                                                                          # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],                                                                                     # RequestCount 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "API 응답 헤더 수신까지의 시간 (초)"                                                                                                                                                    # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix],                                                     # TargetResponseTime 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "ALB 자체·API 대상 HTTP 오류 (5분 합계)"                                                                                                                                             # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "ALB 자체 HTTP 5xx" }],                                                # HTTPCode_ELB_5XX_Count 지표와 대상 차원 표시
        ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Sum", label = "API 대상 HTTP 5xx" }], # HTTPCode_Target_5XX_Count 지표와 대상 차원 표시
        ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "ALB 자체 HTTP 4xx" }],                                                # HTTPCode_ELB_4XX_Count 지표와 대상 차원 표시
        ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Sum", label = "API 대상 HTTP 4xx" }], # HTTPCode_Target_4XX_Count 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title = "API WAF 허용·차단 (5분 합계)"                                                                                                                                                     # 대시보드 패널 제목
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_metric_names.api, "Rule", "ALL", "Region", var.region, { stat = "Sum" }],                                                      # AllowedRequests 지표와 대상 차원 표시
        ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_metric_names.api, "Rule", "ALL", "Region", var.region, { stat = "Sum" }],                                                      # BlockedRequests 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
    {                                                                                                                                                                                     # 목록 항목 설정 시작
      title  = "CloudFront WAF 허용·차단 (5분 합계)"                                                                                                                                             # 대시보드 패널 제목
      region = "us-east-1"                                                                                                                                                                # 리소스 생성·조회 또는 지표 표시 리전
      metrics = [                                                                                                                                                                         # 수집하거나 표시할 지표 목록
        ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_metric_names.cloudfront, "Rule", "ALL", { stat = "Sum" }],                                                                     # AllowedRequests 지표와 대상 차원 표시
        ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_metric_names.cloudfront, "Rule", "ALL", { stat = "Sum" }],                                                                     # BlockedRequests 지표와 대상 차원 표시
      ]                                                                                                                                                                                   # 설정 묶음 끝
    },                                                                                                                                                                                    # 설정 묶음 끝
  ]                                                                                                                                                                                       # 설정 묶음 끝

  log_panels = [                                                                                                                                                                                                                                                                                                                           # Logs Insights 조회 패널 정의
    {                                                                                                                                                                                                                                                                                                                                      # 목록 항목 설정 시작
      title = "ALB 최근 로그 — 접근·연결·상태 검사"                                                                                                                                                                                                                                                                                                    # 대시보드 패널 제목
      query = "SOURCE '${var.log_groups.alb}'\n| fields @timestamp, @logStream, @message\n| sort @timestamp desc\n| limit 100"                                                                                                                                                                                                             # Logs Insights 로그 조회문
    },                                                                                                                                                                                                                                                                                                                                     # 설정 묶음 끝
    {                                                                                                                                                                                                                                                                                                                                      # 목록 항목 설정 시작
      title = "EC2 시스템·API 오류 로그"                                                                                                                                                                                                                                                                                                          # 대시보드 패널 제목
      query = "SOURCE '${var.log_groups.system}'\n| fields @timestamp, @logStream, @message\n| filter @message like /(?i)(error|exception|traceback|failed|out of memory|oom)/\n| sort @timestamp desc\n| limit 100"                                                                                                                       # Logs Insights 로그 조회문
    },                                                                                                                                                                                                                                                                                                                                     # 설정 묶음 끝
    {                                                                                                                                                                                                                                                                                                                                      # 목록 항목 설정 시작
      title = "API WAF 규칙별 차단 (5분 합계)"                                                                                                                                                                                                                                                                                                     # 대시보드 패널 제목
      query = "SOURCE '${var.log_groups.waf_api}'\n| filter action = 'BLOCK'\n| fields coalesce(ruleGroupList.0.terminatingRule.ruleId, ruleGroupList.1.terminatingRule.ruleId, ruleGroupList.2.terminatingRule.ruleId, terminatingRuleId) as blockedRule\n| stats count(*) as blocked by bin(5m), terminatingRuleId, blockedRule"         # Logs Insights 로그 조회문
    },                                                                                                                                                                                                                                                                                                                                     # 설정 묶음 끝
    {                                                                                                                                                                                                                                                                                                                                      # 목록 항목 설정 시작
      title  = "CloudFront WAF 규칙별 차단 (5분 합계)"                                                                                                                                                                                                                                                                                             # 대시보드 패널 제목
      region = "us-east-1"                                                                                                                                                                                                                                                                                                                 # 리소스 생성·조회 또는 지표 표시 리전
      query  = "SOURCE '${var.log_groups.waf_cloudfront}'\n| filter action = 'BLOCK'\n| fields coalesce(ruleGroupList.0.terminatingRule.ruleId, ruleGroupList.1.terminatingRule.ruleId, ruleGroupList.2.terminatingRule.ruleId, terminatingRuleId) as blockedRule\n| stats count(*) as blocked by bin(5m), terminatingRuleId, blockedRule" # Logs Insights 로그 조회문
    },                                                                                                                                                                                                                                                                                                                                     # 설정 묶음 끝
  ]                                                                                                                                                                                                                                                                                                                                        # 설정 묶음 끝
}                                                                                                                                                                                                                                                                                                                                          # 설정 묶음 끝

resource "aws_cloudwatch_dashboard" "main" {       # CloudWatch 대시보드 정의
  dashboard_name = var.name                        # 통합 대시보드 이름
  dashboard_body = jsonencode({                    # 대시보드 위젯 설정을 JSON으로 변환
    start          = "-P7D"                        # 대시보드 기본 조회 기간
    periodOverride = "inherit"                     # 대시보드 시간 범위에 따른 주기 변경 방식
    widgets = concat(                              # 대시보드 위젯 배치 목록
      [{                                           # 경보 상태 위젯 설정 시작
        type   = "alarm"                           # 대시보드 위젯 종류
        x      = 0                                 # 대시보드 위젯 가로 위치
        y      = 0                                 # 대시보드 위젯 세로 위치
        width  = 24                                # 대시보드 위젯 너비
        height = 3                                 # 대시보드 위젯 높이
        properties = {                             # 대시보드 위젯 표시 설정
          title  = "서비스 경보 — 현재 상태"                # 대시보드 패널 제목
          alarms = var.alarm_arns                  # 감시할 경보 목록
        }                                          # 설정 묶음 끝
      }],                                          # 설정 묶음 끝
      [for index, panel in local.metric_panels : { # 패널 정의마다 대시보드 위젯 생성
        type   = "metric"                          # 대시보드 위젯 종류
        x      = (index % 2) * 12                  # 대시보드 위젯 가로 위치
        y      = 3 + floor(index / 2) * 6          # 대시보드 위젯 세로 위치
        width  = 12                                # 대시보드 위젯 너비
        height = 6                                 # 대시보드 위젯 높이
        properties = {                             # 대시보드 위젯 표시 설정
          title   = panel.title                    # 대시보드 패널 제목
          metrics = panel.metrics                  # 수집하거나 표시할 지표 목록
          region  = try(panel.region, var.region)  # 리소스 생성·조회 또는 지표 표시 리전
          period  = 300                            # 지표 집계·경보 평가 주기(초)
          stat    = "Average"                      # 대시보드 지표 집계 방식
          view    = "timeSeries"                   # 대시보드 시각화 방식
        }                                          # 설정 묶음 끝
      }],                                          # 설정 묶음 끝
      [for index, panel in local.log_panels : {    # 패널 정의마다 대시보드 위젯 생성
        type   = "log"                             # 대시보드 위젯 종류
        x      = (index % 2) * 12                  # 대시보드 위젯 가로 위치
        y      = 33 + floor(index / 2) * 6         # 대시보드 위젯 세로 위치
        width  = 12                                # 대시보드 위젯 너비
        height = 6                                 # 대시보드 위젯 높이
        properties = {                             # 대시보드 위젯 표시 설정
          title  = panel.title                     # 대시보드 패널 제목
          query  = panel.query                     # Logs Insights 로그 조회문
          region = try(panel.region, var.region)   # 리소스 생성·조회 또는 지표 표시 리전
          view   = "table"                         # 대시보드 시각화 방식
        }                                          # 설정 묶음 끝
      }],                                          # 설정 묶음 끝
    )                                              # 설정 묶음 끝
  })                                               # 설정 묶음 끝
}                                                  # 설정 묶음 끝
