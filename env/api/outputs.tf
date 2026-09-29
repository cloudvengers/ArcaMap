output "alb" {                          # alb 정보를 호출자에게 반환
  description = "ALB DNS 연결과 대상 그룹 정보." # 반환하는 값의 의미
  value       = module.alb.alb          # 호출자에게 전달할 값
}                                       # 설정 묶음 끝

output "api_url" {                               # api_url 정보를 호출자에게 반환
  description = "DNS 연결과 API 가동 후 사용할 HTTPS 주소." # 반환하는 값의 의미
  value       = "https://${var.api_domain_name}" # 호출자에게 전달할 값
}                                                # 설정 묶음 끝

output "autoscaling_group" {                     # autoscaling_group 정보를 호출자에게 반환
  description = "운영 API ASG 이름과 ARN."            # 반환하는 값의 의미
  value       = module.compute.autoscaling_group # 호출자에게 전달할 값
}                                                # 설정 묶음 끝

output "launch_template" {                     # launch_template 정보를 호출자에게 반환
  description = "운영 API 시작 템플릿과 AMI 정보."       # 반환하는 값의 의미
  value       = module.compute.launch_template # 호출자에게 전달할 값
}                                              # 설정 묶음 끝

output "log_groups" {                                                                   # log_groups 정보를 호출자에게 반환
  description = "API 로그 그룹 이름."                                                         # 반환하는 값의 의미
  value       = { for name, group in module.log_groups : name => group.log_group.name } # 호출자에게 전달할 값
}                                                                                       # 설정 묶음 끝
output "built_image" {                                                                  # built_image 정보를 호출자에게 반환
  description = "빌드·테스트 후 운영 시작 템플릿에 연결하는 AMI."                                         # 반환하는 값의 의미
  value       = module.image_builder.image                                              # 호출자에게 전달할 값
}                                                                                       # 설정 묶음 끝
