module "image_builder" {                 # API AMI 빌드 모듈 연결
  source = "../../modules/image-builder" # 로컬 하위 모듈 경로

  api_subnet_id                       = data.aws_subnet.api["ap-northeast-2a"].id                    # 이미지 빌드 EC2를 배치할 API 서브넷 ID
  api_security_group_id               = data.aws_security_group.api.id                               # API에 연결할 보안 그룹 ID
  image_builder_instance_profile_name = aws_iam_instance_profile.ec2["image_builder"].name           # 이미지 빌드 EC2 인스턴스 프로파일 이름
  image_builder_instance_type         = var.image_builder_instance_type                              # 이미지 빌드 EC2 유형
  image_builder_root_volume_size      = var.image_builder_root_volume_size                           # 이미지 빌드 루트 EBS 용량(GiB)
  image_builder_version               = var.image_builder_version                                    # 이미지 구성요소·레시피 고정 버전
  cloudwatch_agent_version            = var.cloudwatch_agent_version                                 # 설치할 CloudWatch Agent 고정 버전
  cloudwatch_agent_config_json        = jsonencode(local.cloudwatch_agent_config)                    # 이미지에 포함할 Agent 설정 JSON
  cloudwatch_agent_start              = local.cloudwatch_agent_start                                 # 이미지 빌드와 운영 EC2의 Agent 시작 명령
  system_log_group_name               = module.log_groups["ec2_system"].log_group.name               # AMI 테스트에서 확인할 시스템 로그 그룹 이름
  imagebuilder_log_group_name         = module.log_groups["imagebuilder"].log_group.name             # 이미지 빌드·테스트 로그 그룹 이름
  api_installation = {                                                                               # API 설치 파일과 시작 설정 전달
    artifact_uri         = "s3://${aws_s3_object.api.bucket}/${aws_s3_object.api.key}"               # S3 배포 아카이브 URI
    artifact_sha256      = local.api_artifact_sha256                                                 # 배포 파일 다운로드 후 검증할 SHA-256 값
    service_base64       = filebase64("${path.module}/../../app/was/deploy/arcamap-api.service")     # API systemd 서비스 정의의 Base64 값
    secret_loader_base64 = filebase64("${path.module}/../../app/was/deploy/load-runtime-env.sh")     # Secret 조회 스크립트의 Base64 값
    rds_ca_base64        = filebase64("${path.module}/../../app/data/rds-ap-northeast-2-bundle.pem") # 이미지에 설치할 RDS CA 인증서의 Base64 값
    secret_arn           = aws_secretsmanager_secret_version.database.secret_arn                     # 부팅 때 조회할 DB Secret ARN
  }                                                                                                  # 설정 묶음 끝
}                                                                                                    # 설정 묶음 끝
