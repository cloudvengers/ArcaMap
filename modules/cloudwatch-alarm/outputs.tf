output "arn" {
  description = "대시보드에 연결할 CloudWatch 경보 ARN."
  value       = aws_cloudwatch_metric_alarm.main.arn
}

output "name" {                                             # name 정보를 호출자에게 반환
  description = "생성한 CloudWatch 경보 이름."                     # 반환하는 값의 의미
  value       = aws_cloudwatch_metric_alarm.main.alarm_name # 호출자에게 전달할 값
}                                                           # 설정 묶음 끝
