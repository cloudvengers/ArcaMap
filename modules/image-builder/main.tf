resource "aws_imagebuilder_image_recipe" "api" { # 이미지 레시피 정의
  name         = "arcamap-api"                   # AWS 리소스·규칙·작업 이름
  parent_image = data.aws_ami.ubuntu.id          # API AMI의 기반 이미지
  version      = var.image_builder_version       # Image Builder 구성요소·레시피 버전

  component {                                           # 이미지 레시피 구성요소 연결
    component_arn = aws_imagebuilder_component.base.arn # 레시피에 포함할 빌드·검증 구성요소 ARN
  }                                                     # 설정 묶음 끝

  component {                                              # 이미지 레시피 구성요소 연결
    component_arn = aws_imagebuilder_component.fastapi.arn # 레시피에 포함할 빌드·검증 구성요소 ARN
  }                                                        # 설정 묶음 끝

  component {                                           # 이미지 레시피 구성요소 연결
    component_arn = aws_imagebuilder_component.test.arn # 레시피에 포함할 빌드·검증 구성요소 ARN
  }                                                     # 설정 묶음 끝

  component {                                                   # 이미지 레시피 구성요소 연결
    component_arn = aws_imagebuilder_component.fastapi_test.arn # 레시피에 포함할 빌드·검증 구성요소 ARN
  }                                                             # 설정 묶음 끝

  lifecycle {                    # 리소스 생성·교체와 검증 규칙
    create_before_destroy = true # 기존 리소스 제거 전에 대체 리소스 생성
  }                              # 설정 묶음 끝

  block_device_mapping {                               # AMI 블록 장치 구성
    device_name = data.aws_ami.ubuntu.root_device_name # 루트 블록 장치 이름

    ebs {                                                        # 루트 EBS 설정
      volume_type           = "gp3"                              # 루트 EBS 저장 장치 유형
      volume_size           = var.image_builder_root_volume_size # 루트 EBS 용량(GiB)
      encrypted             = true                               # 루트 EBS 암호화 여부
      delete_on_termination = true                               # EC2 종료 시 루트 EBS 삭제 여부
    }                                                            # 설정 묶음 끝
  }                                                              # 설정 묶음 끝
}                                                                # 설정 묶음 끝

resource "aws_imagebuilder_infrastructure_configuration" "api" {          # 이미지 빌드 인프라 정의
  name                          = "arcamap-api"                           # AWS 리소스·규칙·작업 이름
  instance_profile_name         = var.image_builder_instance_profile_name # 빌드 EC2에 연결할 IAM 프로파일
  instance_types                = [var.image_builder_instance_type]       # 빌드 EC2에서 허용할 인스턴스 유형 목록
  subnet_id                     = var.api_subnet_id                       # 리소스를 배치할 서브넷 ID
  security_group_ids            = [var.api_security_group_id]             # 빌드 EC2에 연결할 보안 그룹 ID 목록
  terminate_instance_on_failure = true                                    # 이미지 빌드 실패 시 임시 EC2 종료 여부

  instance_metadata_options {                # 이미지 빌드 EC2의 IMDSv2 설정
    http_tokens                 = "required" # IMDSv2 토큰 요구 방식
    http_put_response_hop_limit = 1          # 메타데이터 토큰 응답의 최대 네트워크 홉
  }                                          # 설정 묶음 끝
}                                            # 설정 묶음 끝

resource "aws_imagebuilder_image" "api" {                                                  # API AMI 빌드 정의
  image_recipe_arn                 = aws_imagebuilder_image_recipe.api.arn                 # 이미지 빌드에 사용할 레시피 ARN
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.api.arn # 빌드 EC2 환경 설정 ARN

  image_tests_configuration {  # AMI 빌드 후 테스트 설정
    image_tests_enabled = true # AMI 빌드 후 테스트 실행 여부
  }                            # 설정 묶음 끝

  logging_configuration {                            # 이미지 빌드 로그 저장 설정
    log_group_name = var.imagebuilder_log_group_name # 로그를 저장할 그룹 이름
  }                                                  # 설정 묶음 끝

  timeouts {        # 이미지 생성 제한 시간
    create = "120m" # AMI 생성 작업 제한 시간
  }                 # 설정 묶음 끝

  lifecycle {                    # 리소스 생성·교체와 검증 규칙
    create_before_destroy = true # 기존 리소스 제거 전에 대체 리소스 생성
  }                              # 설정 묶음 끝
}                                # 설정 묶음 끝
