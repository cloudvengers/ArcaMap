resource "aws_cloudwatch_log_delivery_source" "alb" { # 로그 전달 소스 정의
  for_each = {                                        # 대상 항목별로 블록 반복
    access       = "ALB_ACCESS_LOGS"                  # ALB 접근 로그 유형
    connection   = "ALB_CONNECTION_LOGS"              # ALB 연결 로그 유형
    health_check = "ALB_HEALTH_CHECK_LOGS"            # ALB 상태 검사 로그 유형
  }                                                   # 설정 묶음 끝

  name         = "arcamap-alb-${each.key}" # AWS 리소스·규칙·작업 이름
  log_type     = each.value                # 전달할 로그 종류
  resource_arn = aws_lb.api.arn            # 로그 기록 또는 WAF 보호 대상 ARN
}                                          # 설정 묶음 끝

resource "aws_cloudwatch_log_delivery_destination" "alb" { # 로그 전달 대상 정의
  name          = "arcamap-alb"                            # AWS 리소스·규칙·작업 이름
  output_format = "json"                                   # 전달할 로그의 출력 형식

  delivery_destination_configuration {           # 로그를 저장할 리소스 연결
    destination_resource_arn = var.log_group_arn # 로그를 저장할 버킷·로그 그룹 ARN
  }                                              # 설정 묶음 끝
}                                                # 설정 묶음 끝

resource "aws_cloudwatch_log_delivery" "alb" {      # 로그 전달 연결 정의
  for_each = aws_cloudwatch_log_delivery_source.alb # 대상 항목별로 블록 반복

  delivery_source_name     = each.value.name                                 # 연결할 로그 전달 소스 이름
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.alb.arn # 로그 전달 대상 ARN
}                                                                            # 설정 묶음 끝

resource "aws_cloudwatch_log_group" "waf" {      # CloudWatch 기본 암호화로 API WAF 요청 로그 저장
  name              = "aws-waf-logs-arcamap-api" # WAF 로그 전용 접두사 사용
  region            = "ap-northeast-2"           # 웹 ACL과 같은 리전에 로그 저장
  log_group_class   = "STANDARD"                 # 표준 로그 클래스 사용
  retention_in_days = 14                         # 로그를 14일 보관한 뒤 만료
}                                                # 설정 묶음 끝
