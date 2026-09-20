# 기존 terraform.old 입력 중 이 env가 소유하는 값만 유지합니다.
# app·db 적용 후 네트워크·보안 그룹은 데이터 소스로, RDS는 arcamap-postgres 식별자로 자동 조회합니다.

api_domain_name                     = "api.arcamap.app"
asg_cpu_target                      = 50
asg_health_check_type               = "ELB"
asg_max_size                        = 4
cloudwatch_agent_version            = "1.300072.0b1766"
ec2_instance_profile_name           = "arcamap-api-instance-profile"
ec2_instance_type                   = "t3.small"
ec2_root_volume_size                = 20
frontend_domain_name                = "arcamap.app"
image_builder_instance_profile_name = "arcamap-imagebuilder-instance-profile"
image_builder_instance_type         = "t3.small"
image_builder_root_volume_size      = 20
image_builder_version               = "1.1.2"
log_retention_days                  = 30
route53_role_arn                    = "arn:aws:iam::438465145630:role/Route53"
route53_zone_id                     = "Z05495112R0T3ZW9NIKIZ"
