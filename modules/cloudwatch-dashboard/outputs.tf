output "dashboard" {                                    # dashboard 정보를 호출자에게 반환
  description = "통합 대시보드 이름과 ARN."                      # 반환하는 값의 의미
  value = {                                             # 호출자에게 전달할 값
    name = aws_cloudwatch_dashboard.main.dashboard_name # 호출자에게 전달할 리소스 이름
    arn  = aws_cloudwatch_dashboard.main.dashboard_arn  # 리소스 ARN
  }                                                     # 설정 묶음 끝
}                                                       # 설정 묶음 끝
