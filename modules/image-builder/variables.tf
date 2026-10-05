variable "image_builder_security_group_id" {                  # 입력 변수: network 루트에서 생성한 Image Builder 전용 보안 그룹 ID
  description = "network 루트에서 생성한 Image Builder 전용 보안 그룹 ID." # 입력값의 의미와 사용 범위
  type        = string                                        # 입력값의 자료형
  nullable    = false                                         # null 입력 허용 여부

  validation {                                                                                         # 입력값 검증 규칙
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.image_builder_security_group_id)) # 허용할 입력값 검증 조건
    error_message = "image_builder_security_group_id는 유효한 sg ID여야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                    # 설정 묶음 끝
}                                                                                                      # 설정 묶음 끝

variable "api_subnet_id" {                                # 입력 변수: 이미지 빌드에 사용할 ap-northeast-2a API 서브넷 ID
  description = "이미지 빌드에 사용할 ap-northeast-2a API 서브넷 ID." # 입력값의 의미와 사용 범위
  type        = string                                    # 입력값의 자료형
  nullable    = false                                     # null 입력 허용 여부

  validation {                                                                           # 입력값 검증 규칙
    condition     = can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", var.api_subnet_id)) # 허용할 입력값 검증 조건
    error_message = "api_subnet_id는 유효한 subnet ID여야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                      # 설정 묶음 끝
}                                                                                        # 설정 묶음 끝

variable "cloudwatch_agent_config_json" {                                       # 입력 변수: AMI에 포함할 CloudWatch Agent JSON 설정
  description = "AMI에 포함할 CloudWatch Agent JSON 설정. API 루트에서 시스템 로그 그룹과 연결합니다." # 입력값의 의미와 사용 범위
  type        = string                                                          # 입력값의 자료형
  nullable    = false                                                           # null 입력 허용 여부

  validation {                                                                                                  # 입력값 검증 규칙
    condition     = can(jsondecode(var.cloudwatch_agent_config_json).logs.logs_collected.journald.collect_list) # 허용할 입력값 검증 조건
    error_message = "journald collect_list가 있는 CloudWatch Agent JSON 설정이어야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                             # 설정 묶음 끝
}                                                                                                               # 설정 묶음 끝

variable "cloudwatch_agent_start" {                                                 # 입력 변수: API 루트에서 Image Builder와 운영 EC2에 공통으로 전달하는 CloudWatch Agent 시작 명령
  description = "API 루트에서 Image Builder와 운영 EC2에 공통으로 전달하는 CloudWatch Agent 시작 명령." # 입력값의 의미와 사용 범위
  type        = string                                                              # 입력값의 자료형
  nullable    = false                                                               # null 입력 허용 여부
}                                                                                   # 설정 묶음 끝

variable "cloudwatch_agent_version" {                             # 입력 변수: AMI에 설치할 CloudWatch Agent의 빌드 번호를 포함한 고정 배포 버전
  description = "AMI에 설치할 CloudWatch Agent의 빌드 번호를 포함한 고정 배포 버전." # 입력값의 의미와 사용 범위
  type        = string                                            # 입력값의 자료형
  nullable    = false                                             # null 입력 허용 여부

  validation {                                                                                    # 입력값 검증 규칙
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+b[0-9]+$", var.cloudwatch_agent_version)) # 허용할 입력값 검증 조건
    error_message = "Agent 버전은 1.300072.0b1766처럼 숫자 3구간과 b 뒤 숫자 빌드 번호로 지정해야 합니다."                 # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                               # 설정 묶음 끝
}                                                                                                 # 설정 묶음 끝

variable "image_builder_instance_profile_name" {                           # 입력 변수: API 루트에서 생성해 전달하는 Image Builder 빌드·테스트 EC2 인스턴스 프로파일 이름
  description = "API 루트에서 생성해 전달하는 Image Builder 빌드·테스트 EC2 인스턴스 프로파일 이름." # 입력값의 의미와 사용 범위
  type        = string                                                     # 입력값의 자료형
  nullable    = false                                                      # null 입력 허용 여부

  validation {                                                                                         # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,128}$", var.image_builder_instance_profile_name)) # 허용할 입력값 검증 조건
    error_message = "인스턴스 프로파일 이름은 1~128자의 영숫자 또는 _+=,.@- 문자만 사용할 수 있습니다."                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                    # 설정 묶음 끝
}                                                                                                      # 설정 묶음 끝

variable "image_builder_instance_type" {       # 입력 변수: AMI 빌드·테스트에 사용할 EC2 인스턴스 유형
  description = "AMI 빌드·테스트에 사용할 EC2 인스턴스 유형." # 입력값의 의미와 사용 범위
  type        = string                         # 입력값의 자료형
  nullable    = false                          # null 입력 허용 여부

  validation {                                                                                   # 입력값 검증 규칙
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.image_builder_instance_type)) # 허용할 입력값 검증 조건
    error_message = "인스턴스 유형은 공백 없는 t3.small 등의 형식이어야 합니다."                                      # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                              # 설정 묶음 끝
}                                                                                                # 설정 묶음 끝

variable "image_builder_root_volume_size" { # 입력 변수: AMI 빌드용 루트 EBS 용량(GiB)
  description = "AMI 빌드용 루트 EBS 용량(GiB)."   # 입력값의 의미와 사용 범위
  type        = number                      # 입력값의 자료형
  nullable    = false                       # null 입력 허용 여부

  validation {                                                                                                                                  # 입력값 검증 규칙
    condition     = var.image_builder_root_volume_size >= 20 && floor(var.image_builder_root_volume_size) == var.image_builder_root_volume_size # 허용할 입력값 검증 조건
    error_message = "빌드용 루트 EBS 용량은 20GiB 이상의 정수여야 합니다."                                                                                        # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                             # 설정 묶음 끝
}                                                                                                                                               # 설정 묶음 끝

variable "image_builder_version" {                           # 입력 변수: Image Builder 빌드·테스트 구성요소와 이미지 레시피의 고정 버전
  description = "Image Builder 빌드·테스트 구성요소와 이미지 레시피의 고정 버전." # 입력값의 의미와 사용 범위
  type        = string                                       # 입력값의 자료형
  nullable    = false                                        # null 입력 허용 여부

  validation {                                                                          # 입력값 검증 규칙
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_builder_version)) # 허용할 입력값 검증 조건
    error_message = "Image Builder 버전은 숫자 3구간의 major.minor.patch 형식이어야 합니다."            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                     # 설정 묶음 끝
}                                                                                       # 설정 묶음 끝

variable "imagebuilder_log_group_name" {         # 입력 변수: Image Builder 빌드·테스트 로그 그룹 이름
  description = "Image Builder 빌드·테스트 로그 그룹 이름." # 입력값의 의미와 사용 범위
  type        = string                           # 입력값의 자료형
  nullable    = false                            # null 입력 허용 여부

  validation {                                                                                                                                       # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9/._#-]{1,512}$", var.imagebuilder_log_group_name)) && !startswith(var.imagebuilder_log_group_name, "aws/") # 허용할 입력값 검증 조건
    error_message = "유효한 CloudWatch 로그 그룹 이름을 지정해야 합니다."                                                                                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                  # 설정 묶음 끝
}                                                                                                                                                    # 설정 묶음 끝

variable "system_log_group_name" {                             # 입력 변수: AMI 테스트에서 journald 이벤트 도착을 확인할 시스템 로그 그룹 이름
  description = "AMI 테스트에서 journald 이벤트 도착을 확인할 시스템 로그 그룹 이름." # 입력값의 의미와 사용 범위
  type        = string                                         # 입력값의 자료형
  nullable    = false                                          # null 입력 허용 여부

  validation {                                                                                                                           # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9/._#-]{1,512}$", var.system_log_group_name)) && !startswith(var.system_log_group_name, "aws/") # 허용할 입력값 검증 조건
    error_message = "유효한 CloudWatch 로그 그룹 이름을 지정해야 합니다."                                                                                 # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                      # 설정 묶음 끝
}                                                                                                                                        # 설정 묶음 끝
variable "api_installation" {
  description = "FastAPI 배포 파일, 비밀 값이 없는 DSQL 환경·서비스와 빌드 전용 DB 사용자."
  type = object({
    artifact_uri       = string
    artifact_sha256    = string
    service_base64     = string
    environment_base64 = string
    db_test_user       = string
  })
  nullable = false

  validation {
    condition = (
      can(regex("^[a-f0-9]{64}$", var.api_installation.artifact_sha256)) &&
      can(regex("^s3://arcamap-deploy-[a-z0-9-]+/was/[a-f0-9]{64}\\.tar\\.gz$", var.api_installation.artifact_uri)) &&
      can(base64decode(var.api_installation.service_base64)) &&
      can(base64decode(var.api_installation.environment_base64)) &&
      var.api_installation.db_test_user == "arcamap_imagebuilder"
    )
    error_message = "배포 객체 URI·SHA256·Base64 서비스/환경·빌드 전용 DB 역할이 필요합니다."
  }
}
