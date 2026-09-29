resource "aws_cloudwatch_log_group" "main" { # CloudWatch 로그 그룹 정의
  name              = var.name               # AWS 리소스·규칙·작업 이름
  retention_in_days = var.log_retention_days # 로그 보존 기간(일)
  log_group_class   = "STANDARD"             # CloudWatch 로그 그룹 저장 등급
}                                            # 설정 묶음 끝
