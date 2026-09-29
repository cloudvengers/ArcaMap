output "database" {                                                    # database 정보를 호출자에게 반환
  description = "RDS 식별자와 접속 정보. API 루트는 arcamap-postgres 이름으로 조회합니다." # 반환하는 값의 의미
  value       = module.database.database                               # 호출자에게 전달할 값
}                                                                      # 설정 묶음 끝

output "log_groups" {                                                                   # log_groups 정보를 호출자에게 반환
  description = "DB 로그 그룹 이름."                                                          # 반환하는 값의 의미
  value       = { for name, group in module.log_groups : name => group.log_group.name } # 호출자에게 전달할 값
}                                                                                       # 설정 묶음 끝
