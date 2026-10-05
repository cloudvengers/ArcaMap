output "alb" {
  description = "ALB DNS 연결과 대상 그룹 정보."
  value       = module.alb.alb
}

output "api_url" {
  description = "DNS 연결과 API 가동 후 사용할 HTTPS 주소."
  value       = "https://${var.api_domain_name}"
}

output "autoscaling_group" {
  description = "운영 API ASG 이름과 ARN. 최초 DB 초기화 단계에서는 null."
  value       = try(module.compute[0].autoscaling_group, null)
}

output "launch_template" {
  description = "운영 API 시작 템플릿과 선택한 AMI 정보. 최초 DB 초기화 단계에서는 null."
  value       = try(module.compute[0].launch_template, null)
}

output "log_groups" {
  description = "API 루트의 실제 수집 로그 그룹 이름. 앱 로그는 journald 시스템 로그에 포함됩니다."
  value       = { for name, group in module.log_groups : name => group.log_group.name }
}

output "built_image" {
  description = "보호태그와 배포 가능한 AMI 상태를 조회한 선택 이미지. null이면 ASG 배포 전 단계."
  value = var.api_image == null ? null : {
    image_builder_arn = data.aws_imagebuilder_image.api[0].build_version_arn
    id                = data.aws_ami.api[0].id
    root_device_name  = data.aws_ami.api[0].root_device_name
  }
}

output "image_builder" {
  description = "DB 초기화 뒤 수동 실행할 파이프라인과 수명주기·보호태그 계약."
  value       = try(module.image_builder[0].pipeline, null)
}

output "deployment_bucket" {
  description = "백업 대상 API 배포 파일 버킷 이름과 ARN."
  value = {
    id  = module.deployment_bucket.bucket.id
    arn = module.deployment_bucket.bucket.arn
  }
}

output "ec2_api_role_arn" {
  description = "DB 읽기 역할 매핑 및 EC2 백업/복원 확인에 사용할 운영 API IAM role ARN."
  value       = aws_iam_role.ec2["api"].arn
}

output "image_builder_role_arn" {
  description = "이미지 DB 테스트용 읽기 역할에 AWS IAM GRANT로 연결할 IAM role ARN."
  value       = aws_iam_role.ec2["image_builder"].arn
}

output "database_role_mapping" {
  description = "별도 운영자가 ASG/이미지 테스트 전에 설정할 IAM-to-DB 읽기 역할 매핑. admin 권한은 이 role에 부여하지 않습니다."
  value = { for name, role in aws_iam_role.ec2 : name => {
    iam_role_arn  = role.arn
    database_role = local.database_roles[name]
    cluster_arn   = var.database.cluster_arn
  } }
}
