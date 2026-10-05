resource "aws_launch_template" "api" {  # EC2 시작 템플릿 정의
  name          = "arcamap-api"         # AWS 리소스·규칙·작업 이름
  image_id      = var.image.id          # EC2 시작에 사용할 AMI ID
  instance_type = var.ec2_instance_type # EC2 인스턴스 유형
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = false
    security_groups             = [var.api_security_group_id]
  }

  iam_instance_profile {                 # EC2 IAM 프로파일 연결
    name = var.ec2_instance_profile_name # AWS 리소스·규칙·작업 이름
  }                                      # 설정 묶음 끝

  credit_specification {      # 버스트 CPU 크레딧 설정
    cpu_credits = "unlimited" # 버스트 CPU 크레딧 과금 방식
  }                           # 설정 묶음 끝

  block_device_mappings {                    # EC2 블록 장치 구성
    device_name = var.image.root_device_name # 루트 블록 장치 이름

    ebs {                                              # 루트 EBS 설정
      volume_type           = "gp3"                    # 루트 EBS 저장 장치 유형
      volume_size           = var.ec2_root_volume_size # 루트 EBS 용량(GiB)
      encrypted             = true                     # 루트 EBS 암호화 여부
      delete_on_termination = true                     # EC2 종료 시 루트 EBS 삭제 여부
    }                                                  # 설정 묶음 끝
  }                                                    # 설정 묶음 끝

  metadata_options {                         # EC2 메타데이터 접근 설정
    http_endpoint               = "enabled"  # 인스턴스 메타데이터 서비스 활성화 여부
    http_tokens                 = "required" # IMDSv2 토큰 요구 방식
    http_put_response_hop_limit = 1          # 메타데이터 토큰 응답의 최대 네트워크 홉
  }                                          # 설정 묶음 끝

  monitoring {      # EC2 상세 모니터링 설정
    enabled = false # EC2 상세 모니터링 사용 여부
  }                 # 설정 묶음 끝

  user_data = base64encode(/* 운영 EC2 부팅 시 Agent를 시작할 스크립트 */ <<-BASH
    #!/bin/bash
    set -euo pipefail
    ${var.cloudwatch_agent_start}
  BASH
  ) # 설정 묶음 끝
}   # 설정 묶음 끝
