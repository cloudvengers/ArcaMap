output "alb" {
  description = "ALB DNS 연결과 대상 그룹 정보."
  value       = module.alb.alb
}

output "api_url" {
  description = "DNS 연결과 API 가동 후 사용할 HTTPS 주소."
  value       = "https://${var.api_domain_name}"
}

output "autoscaling_group" {
  description = "운영 API ASG 이름과 ARN."
  value       = module.compute.autoscaling_group
}

output "launch_template" {
  description = "운영 API 시작 템플릿과 AMI 정보."
  value       = module.compute.launch_template
}

output "log_groups" {
  description = "WAS 로그 그룹 이름."
  value       = { for name, group in module.log_groups : name => group.log_group.name }
}
output "built_image" {
  description = "빌드·테스트 후 운영 시작 템플릿에 연결하는 AMI."
  value       = module.image_builder.image
}
