output "log_group" {                                # log_group 정보를 호출자에게 반환
  description = "로그 수집과 전달 설정에 사용할 로그 그룹 이름 및 ARN." # 반환하는 값의 의미
  value = {                                         # 호출자에게 전달할 값
    name = aws_cloudwatch_log_group.main.name       # 호출자에게 전달할 리소스 이름
    arn  = aws_cloudwatch_log_group.main.arn        # 리소스 ARN
  }                                                 # 설정 묶음 끝
}                                                   # 설정 묶음 끝
