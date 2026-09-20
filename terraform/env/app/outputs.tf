output "alb_security_group_id" {
  description = "공개 ALB 보안 그룹 ID."
  value       = module.security.alb_security_group_id
}

output "api_security_group_id" {
  description = "API와 이미지 빌드에 사용할 보안 그룹 ID."
  value       = module.security.api_security_group_id
}

output "api_subnet_ids" {
  description = "AZ별 API 사설 서브넷 ID. was는 이름 태그로 조회합니다."
  value       = module.network.api_subnet_ids
}

output "database_security_group_id" {
  description = "DB 보안 그룹 ID. db는 VPC와 보안 그룹 이름으로 조회합니다."
  value       = module.security.database_security_group_id
}

output "database_subnet_ids" {
  description = "AZ별 DB 격리 서브넷 ID. db는 이름 태그로 조회합니다."
  value       = module.network.database_subnet_ids
}

output "public_subnet_ids" {
  description = "AZ별 공개 서브넷 ID. was는 이름 태그로 조회합니다."
  value       = module.network.public_subnet_ids
}

output "vpc_id" {
  description = "공통 VPC ID."
  value       = module.network.vpc_id
}
