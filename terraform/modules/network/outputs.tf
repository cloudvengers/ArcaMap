output "api_subnet_ids" {
  description = "AZ별 API 사설 서브넷 ID. NAT 라우팅 연결 완료 후 사용할 수 있습니다."
  value       = { for az, subnet in aws_subnet.api : az => subnet.id }

  # 이미지 빌드와 API 실행에 필요한 외부 HTTPS 경로가 먼저 완성되어야 합니다.
  depends_on = [aws_route_table_association.api]
}

output "database_subnet_ids" {
  description = "AZ별 DB 격리 서브넷 ID."
  value       = { for az, subnet in aws_subnet.database : az => subnet.id }
  depends_on  = [aws_route_table_association.database]
}

output "public_subnet_ids" {
  description = "AZ별 ALB용 공개 서브넷 ID."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
  depends_on  = [aws_route_table_association.public]
}

output "vpc_id" {
  description = "Arcamap VPC ID."
  value       = aws_vpc.main.id
}
