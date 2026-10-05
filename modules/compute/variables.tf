variable "api_security_group_id" {               # 입력 변수: network 루트에서 생성한 API 보안 그룹 ID
  description = "network 루트에서 생성한 API 보안 그룹 ID." # 입력값의 의미와 사용 범위
  type        = string                           # 입력값의 자료형
  nullable    = false                            # null 입력 허용 여부

  validation {                                                                               # 입력값 검증 규칙
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.api_security_group_id)) # 허용할 입력값 검증 조건
    error_message = "api_security_group_id는 유효한 sg ID여야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                          # 설정 묶음 끝
}                                                                                            # 설정 묶음 끝

variable "api_subnet_ids" {                 # 입력 변수: 운영 AZ의 API 사설 서브넷 ID 한 개
  description = "운영 AZ의 API 사설 서브넷 ID 한 개." # 입력값의 의미와 사용 범위
  type        = list(string)                # 입력값의 자료형
  nullable    = false                       # null 입력 허용 여부

  validation {                                                                                                                                         # 입력값 검증 규칙
    condition     = length(var.api_subnet_ids) == 1 && alltrue([for id in var.api_subnet_ids : can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", id))]) # 허용할 입력값 검증 조건
    error_message = "api_subnet_ids는 운영 AZ의 유효한 서브넷 ID 한 개여야 합니다."                                                                                     # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                    # 설정 묶음 끝
}                                                                                                                                                      # 설정 묶음 끝

variable "asg_cpu_target" {                   # 입력 변수: Auto Scaling 목표 CPU 사용률(%)
  description = "Auto Scaling 목표 CPU 사용률(%)." # 입력값의 의미와 사용 범위
  type        = number                        # 입력값의 자료형
  nullable    = false                         # null 입력 허용 여부

  validation {                                                          # 입력값 검증 규칙
    condition     = var.asg_cpu_target > 0 && var.asg_cpu_target <= 100 # 허용할 입력값 검증 조건
    error_message = "CPU 목표 사용률은 0보다 크고 100 이하여야 합니다."                  # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                     # 설정 묶음 끝
}                                                                       # 설정 묶음 끝

variable "asg_health_check_type" {                                       # 입력 변수: Auto Scaling의 고장 판단 기준
  description = "Auto Scaling의 고장 판단 기준. 검증된 API AMI의 ALB 상태 검사를 사용합니다." # 입력값의 의미와 사용 범위
  type        = string                                                   # 입력값의 자료형
  default     = "ELB"                                                    # 입력을 생략했을 때 사용할 기본값
  nullable    = false                                                    # null 입력 허용 여부

  validation {                                                          # 입력값 검증 규칙
    condition     = contains(["EC2", "ELB"], var.asg_health_check_type) # 허용할 입력값 검증 조건
    error_message = "상태 검사 유형은 EC2 또는 ELB여야 합니다."                       # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                     # 설정 묶음 끝
}                                                                       # 설정 묶음 끝

variable "asg_max_size" {                     # 입력 변수: Auto Scaling 그룹의 최대 EC2 대수
  description = "Auto Scaling 그룹의 최대 EC2 대수." # 입력값의 의미와 사용 범위
  type        = number                        # 입력값의 자료형
  nullable    = false                         # null 입력 허용 여부

  validation {                                                                           # 입력값 검증 규칙
    condition     = var.asg_max_size >= 2 && floor(var.asg_max_size) == var.asg_max_size # 허용할 입력값 검증 조건
    error_message = "ASG 최대 대수는 2 이상의 정수여야 하며 v2 기본값은 2입니다."                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                      # 설정 묶음 끝
}                                                                                        # 설정 묶음 끝

variable "asg_memory_target" {                # 입력 변수: Auto Scaling 목표 메모리 사용률(%)
  description = "Auto Scaling 목표 메모리 사용률(%)." # 입력값의 의미와 사용 범위
  type        = number                        # 입력값의 자료형
  nullable    = false                         # null 입력 허용 여부

  validation {                                                                # 입력값 검증 규칙
    condition     = var.asg_memory_target > 0 && var.asg_memory_target <= 100 # 허용할 입력값 검증 조건
    error_message = "메모리 목표 사용률은 0보다 크고 100 이하여야 합니다."                        # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                           # 설정 묶음 끝
}                                                                             # 설정 묶음 끝

variable "asg_name" {                            # 입력 변수: API 루트에서 경보와 공통으로 사용하는 ASG 이름
  description = "API 루트에서 경보와 공통으로 사용하는 ASG 이름." # 입력값의 의미와 사용 범위
  type        = string                           # 입력값의 자료형
  nullable    = false                            # null 입력 허용 여부

  validation {                                                                                                          # 입력값 검증 규칙
    condition     = length(var.asg_name) >= 1 && length(var.asg_name) <= 255 && var.asg_name == trimspace(var.asg_name) # 허용할 입력값 검증 조건
    error_message = "ASG 이름은 앞뒤 공백 없는 1~255자여야 합니다."                                                                    # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                     # 설정 묶음 끝
}                                                                                                                       # 설정 묶음 끝

variable "cloudwatch_agent_start" {                                                 # 입력 변수: API 루트에서 Image Builder와 운영 EC2에 공통으로 전달하는 CloudWatch Agent 시작 명령
  description = "API 루트에서 Image Builder와 운영 EC2에 공통으로 전달하는 CloudWatch Agent 시작 명령." # 입력값의 의미와 사용 범위
  type        = string                                                              # 입력값의 자료형
  nullable    = false                                                               # null 입력 허용 여부
}                                                                                   # 설정 묶음 끝

variable "ec2_instance_profile_name" {                       # 입력 변수: API 루트에서 생성해 전달하는 운영 API EC2 인스턴스 프로파일 이름
  description = "API 루트에서 생성해 전달하는 운영 API EC2 인스턴스 프로파일 이름." # 입력값의 의미와 사용 범위
  type        = string                                       # 입력값의 자료형
  nullable    = false                                        # null 입력 허용 여부

  validation {                                                                               # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,128}$", var.ec2_instance_profile_name)) # 허용할 입력값 검증 조건
    error_message = "인스턴스 프로파일 이름은 1~128자의 영숫자 또는 _+=,.@- 문자만 사용할 수 있습니다."                   # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                          # 설정 묶음 끝
}                                                                                            # 설정 묶음 끝

variable "ec2_instance_type" {        # 입력 변수: 운영 API EC2 인스턴스 유형
  description = "운영 API EC2 인스턴스 유형." # 입력값의 의미와 사용 범위
  type        = string                # 입력값의 자료형
  nullable    = false                 # null 입력 허용 여부

  validation {                                                                         # 입력값 검증 규칙
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.ec2_instance_type)) # 허용할 입력값 검증 조건
    error_message = "인스턴스 유형은 공백 없는 t3.small 등의 형식이어야 합니다."                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                    # 설정 묶음 끝
}                                                                                      # 설정 묶음 끝

variable "ec2_root_volume_size" {        # 입력 변수: 운영 EC2 루트 EBS 용량(GiB)
  description = "운영 EC2 루트 EBS 용량(GiB)." # 입력값의 의미와 사용 범위
  type        = number                   # 입력값의 자료형
  nullable    = false                    # null 입력 허용 여부

  validation {                                                                                                                                                              # 입력값 검증 규칙
    condition     = var.ec2_root_volume_size >= 20 && floor(var.ec2_root_volume_size) == var.ec2_root_volume_size && var.ec2_root_volume_size >= var.image.root_volume_size # 허용할 입력값 검증 조건
    error_message = "운영 루트 EBS 용량은 20GiB 이상의 정수이며 빌드 루트 용량 이상이어야 합니다."                                                                                                      # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                         # 설정 묶음 끝
}                                                                                                                                                                           # 설정 묶음 끝

variable "image" {                                         # 입력 변수: Image Builder의 AMI ID·루트 장치 이름·루트 볼륨 용량
  description = "Image Builder의 AMI ID·루트 장치 이름·루트 볼륨 용량." # 입력값의 의미와 사용 범위
  type = object({                                          # 입력값의 자료형
    id               = string                              # 호출자에게 전달할 리소스 ID
    root_device_name = string                              # AMI의 루트 블록 장치 이름
    root_volume_size = number                              # AMI 루트 볼륨 용량(GiB)
  })                                                       # 설정 묶음 끝
  nullable = false                                         # null 입력 허용 여부

  validation {                                                                                            # 입력값 검증 규칙
    condition = (                                                                                         # 허용할 입력값 검증 조건
      can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.image.id)) &&                                     # AMI ID 형식 검사
      can(regex("^/dev/[A-Za-z0-9]+$", var.image.root_device_name)) &&                                    # 루트 블록 장치 경로 형식 검사
      var.image.root_volume_size >= 20 && floor(var.image.root_volume_size) == var.image.root_volume_size # AMI 루트 볼륨이 20GiB 이상의 정수인지 검사
    )                                                                                                     # 설정 묶음 끝
    error_message = "유효한 AMI ID·/dev/ 장치 이름과 20GiB 이상의 정수 루트 볼륨 용량을 지정해야 합니다."                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                       # 설정 묶음 끝
}                                                                                                         # 설정 묶음 끝

variable "instance_refresh_alarm_names" {                               # 입력 변수: Instance Refresh 실패 및 자동 롤백을 판단할 기존 CloudWatch 경보 이름
  description = "Instance Refresh 실패 및 자동 롤백을 판단할 기존 CloudWatch 경보 이름." # 입력값의 의미와 사용 범위
  type        = list(string)                                            # 입력값의 자료형
  nullable    = false                                                   # null 입력 허용 여부

  validation {                                                                                                                                                                                                            # 입력값 검증 규칙
    condition     = length(var.instance_refresh_alarm_names) >= 1 && length(var.instance_refresh_alarm_names) <= 10 && alltrue([for name in var.instance_refresh_alarm_names : length(name) >= 1 && length(name) <= 255]) # 허용할 입력값 검증 조건
    error_message = "1~255자 경보 이름을 1~10개 지정해야 합니다."                                                                                                                                                                       # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                                       # 설정 묶음 끝
}                                                                                                                                                                                                                         # 설정 묶음 끝

variable "target_group_arn" {                          # 입력 변수: HTTPS 리스너 연결이 완료된 ALB API 대상 그룹 ARN
  description = "HTTPS 리스너 연결이 완료된 ALB API 대상 그룹 ARN." # 입력값의 의미와 사용 범위
  type        = string                                 # 입력값의 자료형
  nullable    = false                                  # null 입력 허용 여부

  validation {                                                                                                                              # 입력값 검증 규칙
    condition     = can(regex("^arn:aws:elasticloadbalancing:ap-northeast-2:[0-9]{12}:targetgroup/[^/]+/[0-9a-f]+$", var.target_group_arn)) # 허용할 입력값 검증 조건
    error_message = "서울 리전 ALB 대상 그룹 ARN을 지정해야 합니다."                                                                                        # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                         # 설정 묶음 끝
}                                                                                                                                           # 설정 묶음 끝
