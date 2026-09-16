output "log_group" {
  description = "로그 수집과 전달 설정에 사용할 로그 그룹 이름 및 ARN."
  value = {
    name = aws_cloudwatch_log_group.main.name
    arn  = aws_cloudwatch_log_group.main.arn
  }
}
