output "database" {
  description = "DSQL 클러스터·리전·PrivateLink 접속 정보. API·관측·백업 루트에 필요한 필드를 명시 입력으로 전달합니다."
  value       = module.database.database
}
