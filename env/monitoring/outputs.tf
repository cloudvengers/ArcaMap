output "dashboard" {                                   # dashboard 정보를 호출자에게 반환
  description = "Terraform으로 관리하는 통합 CloudWatch 대시보드." # 반환하는 값의 의미
  value       = module.dashboard.dashboard             # 호출자에게 전달할 값
}                                                      # 설정 묶음 끝
