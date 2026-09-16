variable "api_security_group_id" {
  description = "app에서 생성한 API 보안 그룹 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.api_security_group_id))
    error_message = "api_security_group_id는 유효한 sg ID여야 합니다."
  }
}

variable "api_subnet_id" {
  description = "이미지 빌드에 사용할 ap-northeast-2a API 서브넷 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", var.api_subnet_id))
    error_message = "api_subnet_id는 유효한 subnet ID여야 합니다."
  }
}

variable "cloudwatch_agent_config_json" {
  description = "AMI에 포함할 CloudWatch Agent JSON 설정. WAS 루트에서 시스템 로그 그룹과 연결합니다."
  type        = string
  nullable    = false

  validation {
    condition     = can(jsondecode(var.cloudwatch_agent_config_json).logs.logs_collected.journald.collect_list)
    error_message = "journald collect_list가 있는 CloudWatch Agent JSON 설정이어야 합니다."
  }
}

variable "cloudwatch_agent_start" {
  description = "WAS 루트에서 Image Builder와 운영 EC2에 공통으로 전달하는 CloudWatch Agent 시작 명령."
  type        = string
  nullable    = false
}

variable "cloudwatch_agent_version" {
  description = "AMI에 설치할 CloudWatch Agent의 빌드 번호를 포함한 고정 배포 버전."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+b[0-9]+$", var.cloudwatch_agent_version))
    error_message = "Agent 버전은 1.300072.0b1766처럼 숫자 3구간과 b 뒤 숫자 빌드 번호로 지정해야 합니다."
  }
}

variable "image_builder_instance_profile_name" {
  description = "WAS 루트에서 생성해 전달하는 Image Builder 빌드·테스트 EC2 인스턴스 프로파일 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,128}$", var.image_builder_instance_profile_name))
    error_message = "인스턴스 프로파일 이름은 1~128자의 영숫자 또는 _+=,.@- 문자만 사용할 수 있습니다."
  }
}

variable "image_builder_instance_type" {
  description = "AMI 빌드·테스트에 사용할 EC2 인스턴스 유형."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.image_builder_instance_type))
    error_message = "인스턴스 유형은 공백 없는 t3.small 등의 형식이어야 합니다."
  }
}

variable "image_builder_root_volume_size" {
  description = "AMI 빌드용 루트 EBS 용량(GiB)."
  type        = number
  nullable    = false

  validation {
    condition     = var.image_builder_root_volume_size >= 20 && floor(var.image_builder_root_volume_size) == var.image_builder_root_volume_size
    error_message = "빌드용 루트 EBS 용량은 20GiB 이상의 정수여야 합니다."
  }
}

variable "image_builder_version" {
  description = "Image Builder 빌드·테스트 구성요소와 이미지 레시피의 고정 버전."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_builder_version))
    error_message = "Image Builder 버전은 숫자 3구간의 major.minor.patch 형식이어야 합니다."
  }
}

variable "imagebuilder_log_group_name" {
  description = "Image Builder 빌드·테스트 로그 그룹 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9/._#-]{1,512}$", var.imagebuilder_log_group_name)) && !startswith(var.imagebuilder_log_group_name, "aws/")
    error_message = "유효한 CloudWatch 로그 그룹 이름을 지정해야 합니다."
  }
}

variable "system_log_group_name" {
  description = "AMI 테스트에서 journald 이벤트 도착을 확인할 시스템 로그 그룹 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9/._#-]{1,512}$", var.system_log_group_name)) && !startswith(var.system_log_group_name, "aws/")
    error_message = "유효한 CloudWatch 로그 그룹 이름을 지정해야 합니다."
  }
}
variable "api_installation" {
  description = "FastAPI 배포 파일과 비밀 값이 없는 부팅 설정."
  type = object({
    artifact_uri         = string
    artifact_sha256      = string
    service_base64       = string
    secret_loader_base64 = string
    rds_ca_base64        = string
    secret_arn           = string
  })
  nullable = false
}
