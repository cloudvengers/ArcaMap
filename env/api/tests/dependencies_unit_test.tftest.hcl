# 배포 아카이브·RDS CA 파일을 준비한 뒤 terraform test로 실행합니다.
mock_provider "aws" {                  # AWS API를 호출하지 않는 모의 공급자
  mock_data "aws_vpc" {                # 데이터 조회 결과 모의 설정
    defaults = { id = "vpc-00000000" } # AWS 조회·리소스 결과의 모의 값
  }                                    # 설정 묶음 끝

  mock_data "aws_security_group" {    # 데이터 조회 결과 모의 설정
    defaults = { id = "sg-00000000" } # AWS 조회·리소스 결과의 모의 값
  }                                   # 설정 묶음 끝

  mock_data "aws_acm_certificate" {                                                                                 # 데이터 조회 결과 모의 설정
    defaults = { arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/00000000-0000-0000-0000-000000000000" } # AWS 조회·리소스 결과의 모의 값
  }                                                                                                                 # 설정 묶음 끝

  mock_data "aws_ami" {                 # 데이터 조회 결과 모의 설정
    defaults = {                        # AWS 조회·리소스 결과의 모의 값
      id               = "ami-00000000" # 테스트에서 사용할 모의 리소스 ID
      root_device_name = "/dev/sda1"    # AMI의 루트 블록 장치 이름
    }                                   # 설정 묶음 끝
  }                                     # 설정 묶음 끝

  mock_data "aws_region" {                   # 데이터 조회 결과 모의 설정
    defaults = { region = "ap-northeast-2" } # AWS 조회·리소스 결과의 모의 값
  }                                          # 설정 묶음 끝

  mock_resource "aws_imagebuilder_image" {                             # 리소스 생성 결과 모의 설정
    override_during = plan                                             # 모의 값을 적용할 테스트 단계
    defaults = {                                                       # AWS 조회·리소스 결과의 모의 값
      output_resources = [{                                            # 모의 이미지 빌드 산출물
        amis = [{ region = "ap-northeast-2", image = "ami-00000000" }] # 리전별 AMI 빌드 결과
      }]                                                               # 설정 묶음 끝
    }                                                                  # 설정 묶음 끝
  }                                                                    # 설정 묶음 끝
}                                                                      # 설정 묶음 끝

mock_provider "aws" { # AWS API를 호출하지 않는 모의 공급자
  alias = "dns"       # 공급자 별칭
}                     # 설정 묶음 끝

override_data {                                      # 특정 데이터 조회 결과 대체
  target = data.aws_subnet.public["ap-northeast-2a"] # 모의 값으로 대체할 데이터 소스 주소
  values = { id = "subnet-00000001" }                # 조회 필터 값 또는 테스트 대체 값
}                                                    # 설정 묶음 끝

override_data {                                      # 특정 데이터 조회 결과 대체
  target = data.aws_subnet.public["ap-northeast-2c"] # 모의 값으로 대체할 데이터 소스 주소
  values = { id = "subnet-00000002" }                # 조회 필터 값 또는 테스트 대체 값
}                                                    # 설정 묶음 끝

override_data {                                   # 특정 데이터 조회 결과 대체
  target = data.aws_subnet.api["ap-northeast-2a"] # 모의 값으로 대체할 데이터 소스 주소
  values = { id = "subnet-00000003" }             # 조회 필터 값 또는 테스트 대체 값
}                                                 # 설정 묶음 끝

override_data {                                   # 특정 데이터 조회 결과 대체
  target = data.aws_subnet.api["ap-northeast-2c"] # 모의 값으로 대체할 데이터 소스 주소
  values = { id = "subnet-00000004" }             # 조회 필터 값 또는 테스트 대체 값
}                                                 # 설정 묶음 끝

variables {                       # 모의 테스트용 입력값
  db_password = "MockPassword123" # RDS 비밀번호 입력
}                                 # 설정 묶음 끝

run "deployment_dependencies" { # 모의 계획으로 배포 의존성 검증
  command = plan                # 테스트를 실행할 Terraform 동작

  assert {                                                                                                                         # 배포 의존성 검증
    condition     = module.compute.autoscaling_group.name == local.service_alarms["asg-inservice"].dimensions.AutoScalingGroupName # 모의 계획에서 확인할 의존성 조건
    error_message = "경보가 실제 API ASG를 감시해야 하며, 교체 경보와 ASG 사이에 순환 참조가 없어야 합니다."                                                      # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                # 설정 묶음 끝

  assert {                                                                                 # 배포 의존성 검증
    condition     = module.compute.launch_template.ami_id == module.image_builder.image.id # 모의 계획에서 확인할 의존성 조건
    error_message = "Image Builder의 AMI가 운영 시작 템플릿에 연결되어야 합니다."                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                        # 설정 묶음 끝
}                                                                                          # 설정 묶음 끝
