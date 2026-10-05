# v2 API 기본값입니다. DSQL database와 ACM ARN, DNS IAM은 별도 확인 후 명시 입력합니다.

api_domain_name                     = "api.arcamap.app"
api_image                           = "arn:aws:imagebuilder:ap-northeast-2:565725315772:image/arcamap-api/2.0.0/1"
asg_cpu_target                      = 50
asg_health_check_type               = "ELB"
asg_max_size                        = 2
asg_memory_target                   = 50
certificate_arn                     = "arn:aws:acm:ap-northeast-2:565725315772:certificate/2cd8ab18-eac0-4a8c-b362-a68d80bd74cb"
cloudwatch_agent_version            = "1.300072.0b1766"
ec2_instance_profile_name           = "arcamap-api-instance-profile"
ec2_instance_type                   = "t3.small"
ec2_root_volume_size                = 20
enable_image_builder                = true
frontend_domain_name                = "arcamap.app"
image_builder_instance_profile_name = "arcamap-imagebuilder-instance-profile"
image_builder_instance_type         = "t3.small"
image_builder_root_volume_size      = 20
image_builder_version               = "2.0.0"
log_retention_days                  = 30
route53_role_arn                    = "arn:aws:iam::438465145630:role/Route53"
route53_zone_id                     = "Z05495112R0T3ZW9NIKIZ"

database = {
  cluster_id  = "lfud6y5astoc75e2ftlfumkuri"
  cluster_arn = "arn:aws:dsql:ap-northeast-2:565725315772:cluster/lfud6y5astoc75e2ftlfumkuri"
  region      = "ap-northeast-2"
  host        = "lfud6y5astoc75e2ftlfumkuri.dsql-zcsu.ap-northeast-2.on.aws"
  auth_host   = "lfud6y5astoc75e2ftlfumkuri.dsql-zcsu.ap-northeast-2.on.aws"
  dbname      = "postgres"
  port        = 5432
}
