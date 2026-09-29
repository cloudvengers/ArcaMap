output "alb_security_group_id" {                              # alb_security_group_id 정보를 호출자에게 반환
  description = "HTTP·HTTPS 수신과 API 송신 규칙이 연결된 ALB 보안 그룹 ID." # 반환하는 값의 의미
  value       = aws_security_group.alb.id                     # 호출자에게 전달할 값
  depends_on = [                                              # 참조만으로 표현되지 않는 선행 작업 지정
    aws_vpc_security_group_ingress_rule.alb_http,             # ALB 보안 그룹 반환 전에 HTTP 허용 규칙 연결
    aws_vpc_security_group_ingress_rule.alb_https,            # ALB 보안 그룹 반환 전에 HTTPS 허용 규칙 연결
    aws_vpc_security_group_egress_rule.alb_api,               # ALB 보안 그룹 반환 전에 API 송신 규칙 연결
  ]                                                           # 설정 묶음 끝
}                                                             # 설정 묶음 끝

output "api_security_group_id" {                                 # api_security_group_id 정보를 호출자에게 반환
  description = "ALB 수신·DB 송신·외부 HTTPS 송신 규칙이 연결된 API 보안 그룹 ID." # 반환하는 값의 의미
  value       = aws_security_group.api.id                        # 호출자에게 전달할 값

  # 이미지 빌드와 ASG 생성 전에 기존 보안 규칙이 적용되어야 합니다.
  depends_on = [                                     # 참조만으로 표현되지 않는 선행 작업 지정
    aws_vpc_security_group_ingress_rule.api_alb,     # API 보안 그룹 반환 전에 ALB 수신 규칙 연결
    aws_vpc_security_group_egress_rule.api_database, # API 보안 그룹 반환 전에 DB 송신 규칙 연결
    aws_vpc_security_group_egress_rule.api_https,    # API 보안 그룹 반환 전에 HTTPS 송신 규칙 연결
  ]                                                  # 설정 묶음 끝
}                                                    # 설정 묶음 끝

output "database_security_group_id" {                              # database_security_group_id 정보를 호출자에게 반환
  description = "API 보안 그룹의 PostgreSQL 접속만 허용하는 DB 보안 그룹 ID."      # 반환하는 값의 의미
  value       = aws_security_group.database.id                     # 호출자에게 전달할 값
  depends_on  = [aws_vpc_security_group_ingress_rule.database_api] # 참조만으로 표현되지 않는 선행 작업 지정
}                                                                  # 설정 묶음 끝
