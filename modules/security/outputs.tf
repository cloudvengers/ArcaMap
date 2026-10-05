output "alb_security_group_id" {                              # alb_security_group_id 정보를 호출자에게 반환
  description = "HTTP·HTTPS 수신과 API 송신 규칙이 연결된 ALB 보안 그룹 ID." # 반환하는 값의 의미
  value       = aws_security_group.alb.id                     # 호출자에게 전달할 값
  depends_on = [                                              # 참조만으로 표현되지 않는 선행 작업 지정
    aws_vpc_security_group_ingress_rule.alb_http,             # ALB 보안 그룹 반환 전에 HTTP 허용 규칙 연결
    aws_vpc_security_group_ingress_rule.alb_https,            # ALB 보안 그룹 반환 전에 HTTPS 허용 규칙 연결
    aws_vpc_security_group_egress_rule.alb_api,               # ALB 보안 그룹 반환 전에 API 송신 규칙 연결
  ]                                                           # 설정 묶음 끝
}                                                             # 설정 묶음 끝

output "api_security_group_id" {                                                      # api_security_group_id 정보를 호출자에게 반환
  description = "ALB 8080 수신·DSQL Endpoint 5432 접속·외부 HTTPS 송신 규칙이 연결된 API 보안 그룹 ID." # 반환하는 값의 의미
  value       = aws_security_group.api.id                                             # 호출자에게 전달할 값

  # ASG 생성 전에 API와 Endpoint 양쪽의 보안 규칙이 적용되어야 합니다.
  depends_on = [                                  # 참조만으로 표현되지 않는 선행 작업 지정
    aws_vpc_security_group_ingress_rule.api_alb,  # API 보안 그룹 반환 전에 ALB 수신 규칙 연결
    aws_vpc_security_group_egress_rule.api_dsql,  # API 보안 그룹 반환 전에 DSQL 송신 규칙 연결
    aws_vpc_security_group_egress_rule.api_https, # API 보안 그룹 반환 전에 HTTPS 송신 규칙 연결
    aws_vpc_security_group_ingress_rule.dsql_api,
  ] # 설정 묶음 끝
}   # 설정 묶음 끝

output "dsql_endpoint_security_group_id" {
  description = "API·Image Builder 보안 그룹의 TCP 5432 접속만 허용하는 DSQL Endpoint 보안 그룹 ID."
  value       = aws_security_group.dsql_endpoint.id
  depends_on = [
    aws_vpc_security_group_ingress_rule.dsql_api,
    aws_vpc_security_group_ingress_rule.dsql_image_builder,
  ]
}

output "image_builder_security_group_id" {
  description = "인바운드 없이 외부 HTTPS 443·DSQL Endpoint 5432 접속만 허용하는 Image Builder 보안 그룹 ID."
  value       = aws_security_group.image_builder.id
  depends_on = [
    aws_vpc_security_group_egress_rule.image_builder_https,
    aws_vpc_security_group_egress_rule.image_builder_dsql,
    aws_vpc_security_group_ingress_rule.dsql_image_builder,
  ]
}
