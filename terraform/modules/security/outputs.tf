output "alb_security_group_id" {
  description = "HTTP·HTTPS 수신과 API 송신 규칙이 연결된 ALB 보안 그룹 ID."
  value       = aws_security_group.alb.id
  depends_on = [
    aws_vpc_security_group_ingress_rule.alb_http,
    aws_vpc_security_group_ingress_rule.alb_https,
    aws_vpc_security_group_egress_rule.alb_api,
  ]
}

output "api_security_group_id" {
  description = "ALB 수신·DB 송신·외부 HTTPS 송신 규칙이 연결된 API 보안 그룹 ID."
  value       = aws_security_group.api.id

  # 이미지 빌드와 ASG 생성 전에 기존 보안 규칙이 적용되어야 합니다.
  depends_on = [
    aws_vpc_security_group_ingress_rule.api_alb,
    aws_vpc_security_group_egress_rule.api_database,
    aws_vpc_security_group_egress_rule.api_https,
  ]
}

output "database_security_group_id" {
  description = "API 보안 그룹의 PostgreSQL 접속만 허용하는 DB 보안 그룹 ID."
  value       = aws_security_group.database.id
  depends_on  = [aws_vpc_security_group_ingress_rule.database_api]
}
