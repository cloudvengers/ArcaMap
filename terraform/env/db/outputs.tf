output "database" {
  description = "RDS 식별자와 접속 정보. WAS는 arcamap-postgres 이름으로 조회합니다."
  value       = module.database.database
}

output "log_groups" {
  description = "DB 로그 그룹 이름."
  value       = { for name, group in module.log_groups : name => group.log_group.name }
}
