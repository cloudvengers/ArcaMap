output "alb_security_group_id" {                      # alb_security_group_id 정보를 호출자에게 반환
  description = "공개 ALB 보안 그룹 ID."                    # 반환하는 값의 의미
  value       = module.security.alb_security_group_id # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "api_security_group_id" {                      # api_security_group_id 정보를 호출자에게 반환
  description = "API와 이미지 빌드에 사용할 보안 그룹 ID."          # 반환하는 값의 의미
  value       = module.security.api_security_group_id # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "api_subnet_ids" {                               # api_subnet_ids 정보를 호출자에게 반환
  description = "AZ별 API 사설 서브넷 ID. was는 이름 태그로 조회합니다." # 반환하는 값의 의미
  value       = module.network.api_subnet_ids           # 호출자에게 전달할 값
}                                                       # 설정 묶음 끝

output "database_security_group_id" {                      # database_security_group_id 정보를 호출자에게 반환
  description = "DB 보안 그룹 ID. db는 VPC와 보안 그룹 이름으로 조회합니다."  # 반환하는 값의 의미
  value       = module.security.database_security_group_id # 호출자에게 전달할 값
}                                                          # 설정 묶음 끝

output "database_subnet_ids" {                        # database_subnet_ids 정보를 호출자에게 반환
  description = "AZ별 DB 격리 서브넷 ID. db는 이름 태그로 조회합니다." # 반환하는 값의 의미
  value       = module.network.database_subnet_ids    # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "public_subnet_ids" {                        # public_subnet_ids 정보를 호출자에게 반환
  description = "AZ별 공개 서브넷 ID. was는 이름 태그로 조회합니다." # 반환하는 값의 의미
  value       = module.network.public_subnet_ids    # 호출자에게 전달할 값
}                                                   # 설정 묶음 끝

output "vpc_id" {                     # vpc_id 정보를 호출자에게 반환
  description = "공통 VPC ID."          # 반환하는 값의 의미
  value       = module.network.vpc_id # 호출자에게 전달할 값
}                                     # 설정 묶음 끝
