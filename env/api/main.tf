module "compute" {                 # API EC2·Auto Scaling 모듈 연결
  source = "../../modules/compute" # 로컬 하위 모듈 경로

  api_subnet_ids            = [for subnet in data.aws_subnet.api : subnet.id] # API 인스턴스를 배치할 서브넷 ID 목록
  api_security_group_id     = data.aws_security_group.api.id                  # API에 연결할 보안 그룹 ID
  image                     = module.image_builder.image                      # 운영에 사용할 AMI 정보
  target_group_arn          = module.alb.alb.target_group_arn                 # API 요청을 전달할 대상 그룹 ARN
  ec2_instance_profile_name = aws_iam_instance_profile.ec2["api"].name        # 운영 API EC2 인스턴스 프로파일 이름
  ec2_instance_type         = var.ec2_instance_type                           # 운영 API EC2 인스턴스 유형
  ec2_root_volume_size      = var.ec2_root_volume_size                        # 운영 EC2 루트 EBS 용량(GiB)
  asg_max_size              = var.asg_max_size                                # ASG 최대 인스턴스 수
  asg_cpu_target            = var.asg_cpu_target                              # ASG 목표 CPU 사용률(%)
  asg_name                  = local.api_asg_name                              # API Auto Scaling 그룹 이름
  instance_refresh_alarm_names = [                                            # 교체 실패와 롤백을 판단할 경보 이름
    module.service_alarms["alb-healthy-hosts"].name,                          # 인스턴스 교체 실패 시 롤백을 판단할 경보
    module.service_alarms["alb-5xx"].name,                                    # 인스턴스 교체 실패 시 롤백을 판단할 경보
    module.service_alarms["api-5xx"].name,                                    # 인스턴스 교체 실패 시 롤백을 판단할 경보
  ]                                                                           # 설정 묶음 끝
  asg_memory_target      = var.asg_memory_target                              # ASG 목표 메모리 사용률(%)
  asg_health_check_type  = var.asg_health_check_type                          # ASG 인스턴스 상태 판단 방식
  cloudwatch_agent_start = local.cloudwatch_agent_start                       # 이미지 빌드와 운영 EC2의 Agent 시작 명령
}                                                                             # 설정 묶음 끝
