output "alb_security_group_id" {                      # alb_security_group_id 정보를 호출자에게 반환
  description = "공개 ALB 보안 그룹 ID."                    # 반환하는 값의 의미
  value       = module.security.alb_security_group_id # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "api_security_group_id" {                      # api_security_group_id 정보를 호출자에게 반환
  description = "운영 API 전용 보안 그룹 ID."                 # 반환하는 값의 의미
  value       = module.security.api_security_group_id # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "api_subnet_ids" {                                                              # api_subnet_ids 정보를 호출자에게 반환
  description = "운영 AZ ap-northeast-2a의 API·빌드·DSQL Endpoint 사설 서브넷 ID. 이름 태그로 조회합니다." # 반환하는 값의 의미
  value       = module.network.api_subnet_ids                                          # 호출자에게 전달할 값
}                                                                                      # 설정 묶음 끝

output "dsql_endpoint_security_group_id" {
  description = "DSQL Endpoint 전용 보안 그룹 ID. VPC와 arcamap-dsql-endpoint 이름으로 조회합니다."
  value       = module.security.dsql_endpoint_security_group_id
}

output "image_builder_security_group_id" {
  description = "Image Builder 전용 보안 그룹 ID. VPC와 arcamap-imagebuilder 이름으로 조회합니다."
  value       = module.security.image_builder_security_group_id
}

output "notification_topic_arn" {
  description = "같은 계정의 arcamap 경보를 수신하는 SNS 표준 토픽 ARN. API·DB는 arcamap-operations 이름으로 조회합니다."
  value       = aws_sns_topic.operations.arn
  depends_on  = [aws_sns_topic_policy.operations]
}

output "public_subnet_ids" {                           # public_subnet_ids 정보를 호출자에게 반환
  description = "ALB용 공개 서브넷 2a·2c의 ID. 이름 태그로 조회합니다." # 반환하는 값의 의미
  value       = module.network.public_subnet_ids       # 호출자에게 전달할 값
}                                                      # 설정 묶음 끝

output "vpc_id" {                     # vpc_id 정보를 호출자에게 반환
  description = "공통 VPC ID."          # 반환하는 값의 의미
  value       = module.network.vpc_id # 호출자에게 전달할 값
}                                     # 설정 묶음 끝
