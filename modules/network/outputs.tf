output "api_subnet_ids" {                                                                            # api_subnet_ids 정보를 호출자에게 반환
  description = "운영 AZ ap-northeast-2a의 API·빌드·DSQL Endpoint 사설 서브넷 ID. NAT 라우팅 연결 완료 후 사용할 수 있습니다." # 반환하는 값의 의미
  value       = { for az, subnet in aws_subnet.api : az => subnet.id }                               # 호출자에게 전달할 값

  # 이미지 빌드와 API 실행에 필요한 외부 HTTPS 경로가 먼저 완성되어야 합니다.
  depends_on = [aws_route_table_association.api] # 참조만으로 표현되지 않는 선행 작업 지정
}                                                # 설정 묶음 끝

output "public_subnet_ids" {                                              # public_subnet_ids 정보를 호출자에게 반환
  description = "AZ별 ALB용 공개 서브넷 ID."                                     # 반환하는 값의 의미
  value       = { for az, subnet in aws_subnet.public : az => subnet.id } # 호출자에게 전달할 값
  depends_on  = [aws_route_table_association.public]                      # 참조만으로 표현되지 않는 선행 작업 지정
}                                                                         # 설정 묶음 끝

output "vpc_id" {                 # vpc_id 정보를 호출자에게 반환
  description = "Arcamap VPC ID." # 반환하는 값의 의미
  value       = aws_vpc.main.id   # 호출자에게 전달할 값
}                                 # 설정 묶음 끝
