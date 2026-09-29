variable "api_domain_name" {           # 입력 변수: EC2 API의 DNS 호스트 이름
  description = "EC2 API의 DNS 호스트 이름." # 입력값의 의미와 사용 범위
  type        = string                 # 입력값의 자료형
  nullable    = false                  # null 입력 허용 여부

  validation {                                                                                                                                                                                                                                            # 입력값 검증 규칙
    condition     = length(var.api_domain_name) <= 253 && can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.api_domain_name)) && lower(var.api_domain_name) != lower(var.frontend_domain_name) # 허용할 입력값 검증 조건
    error_message = "도메인은 스킴·포트·경로·공백이 없는 253자 이하 DNS 호스트 이름이어야 하며 프런트엔드와 API 주소는 서로 달라야 합니다."                                                                                                                                                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                                                                       # 설정 묶음 끝
}                                                                                                                                                                                                                                                         # 설정 묶음 끝

variable "asg_cpu_target" {                   # 입력 변수: Auto Scaling 목표 CPU 사용률(%)
  description = "Auto Scaling 목표 CPU 사용률(%)." # 입력값의 의미와 사용 범위
  type        = number                        # 입력값의 자료형
  nullable    = false                         # null 입력 허용 여부

  validation {                                                          # 입력값 검증 규칙
    condition     = var.asg_cpu_target > 0 && var.asg_cpu_target <= 100 # 허용할 입력값 검증 조건
    error_message = "CPU 목표 사용률은 0보다 크고 100 이하여야 합니다."                  # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                     # 설정 묶음 끝
}                                                                       # 설정 묶음 끝

variable "asg_health_check_type" {                                               # 입력 변수: Auto Scaling의 고장 판단 기준
  description = "Auto Scaling의 고장 판단 기준. 초기 배포는 EC2, API 설치·응답 확인 후 ELB로 전환합니다." # 입력값의 의미와 사용 범위
  type        = string                                                           # 입력값의 자료형
  default     = "EC2"                                                            # 입력을 생략했을 때 사용할 기본값
  nullable    = false                                                            # null 입력 허용 여부

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
    error_message = "ASG 최대 대수는 고정 최소 대수인 2 이상의 정수여야 합니다."                               # 검증 조건을 만족하지 않을 때 표시할 오류
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

variable "cloudwatch_agent_version" {                             # 입력 변수: AMI에 설치할 CloudWatch Agent의 빌드 번호를 포함한 고정 배포 버전
  description = "AMI에 설치할 CloudWatch Agent의 빌드 번호를 포함한 고정 배포 버전." # 입력값의 의미와 사용 범위
  type        = string                                            # 입력값의 자료형
  nullable    = false                                             # null 입력 허용 여부

  validation {                                                                                    # 입력값 검증 규칙
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+b[0-9]+$", var.cloudwatch_agent_version)) # 허용할 입력값 검증 조건
    error_message = "Agent 버전은 1.300072.0b1766처럼 숫자 3구간과 b 뒤 숫자 빌드 번호로 지정해야 합니다."                 # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                               # 설정 묶음 끝
}                                                                                                 # 설정 묶음 끝

variable "ec2_instance_profile_name" {                       # 입력 변수: API 루트에서 생성해 운영 API EC2에 연결할 인스턴스 프로파일 이름
  description = "API 루트에서 생성해 운영 API EC2에 연결할 인스턴스 프로파일 이름." # 입력값의 의미와 사용 범위
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

  validation {                                                                                                                                                                      # 입력값 검증 규칙
    condition     = var.ec2_root_volume_size >= 20 && floor(var.ec2_root_volume_size) == var.ec2_root_volume_size && var.ec2_root_volume_size >= var.image_builder_root_volume_size # 허용할 입력값 검증 조건
    error_message = "운영 루트 EBS 용량은 20GiB 이상의 정수이며 빌드 루트 용량 이상이어야 합니다."                                                                                                              # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                 # 설정 묶음 끝
}                                                                                                                                                                                   # 설정 묶음 끝

variable "frontend_domain_name" {       # 입력 변수: 정적 프런트엔드의 DNS 호스트 이름
  description = "정적 프런트엔드의 DNS 호스트 이름." # 입력값의 의미와 사용 범위
  type        = string                  # 입력값의 자료형
  nullable    = false                   # null 입력 허용 여부

  validation {                                                                                                                                                                                     # 입력값 검증 규칙
    condition     = length(var.frontend_domain_name) <= 253 && can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.frontend_domain_name)) # 허용할 입력값 검증 조건
    error_message = "도메인은 스킴·포트·경로·공백이 없는 253자 이하 DNS 호스트 이름이어야 하며 프런트엔드와 API 주소는 서로 달라야 합니다."                                                                                                     # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                # 설정 묶음 끝
}                                                                                                                                                                                                  # 설정 묶음 끝

variable "image_builder_instance_profile_name" {                           # 입력 변수: API 루트에서 생성해 Image Builder 빌드·테스트 EC2에 연결할 인스턴스 프로파일 이름
  description = "API 루트에서 생성해 Image Builder 빌드·테스트 EC2에 연결할 인스턴스 프로파일 이름." # 입력값의 의미와 사용 범위
  type        = string                                                     # 입력값의 자료형
  nullable    = false                                                      # null 입력 허용 여부

  validation {                                                                                         # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,128}$", var.image_builder_instance_profile_name)) # 허용할 입력값 검증 조건
    error_message = "인스턴스 프로파일 이름은 1~128자의 영숫자 또는 _+=,.@- 문자만 사용할 수 있습니다."                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                    # 설정 묶음 끝

  validation {                                                                                             # 입력값 검증 규칙
    condition     = lower(var.image_builder_instance_profile_name) != lower(var.ec2_instance_profile_name) # 허용할 입력값 검증 조건
    error_message = "운영 API와 Image Builder의 인스턴스 프로파일 이름은 서로 달라야 합니다."                                     # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                        # 설정 묶음 끝
}                                                                                                          # 설정 묶음 끝

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

variable "log_retention_days" {                       # 입력 변수: CloudWatch와 CloudFront 로그 보존 기간(일)
  description = "CloudWatch와 CloudFront 로그 보존 기간(일)." # 입력값의 의미와 사용 범위
  type        = number                                # 입력값의 자료형
  nullable    = false                                 # null 입력 허용 여부

  validation {                                                                                                                                                  # 입력값 검증 규칙
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days) # 허용할 입력값 검증 조건
    error_message = "로그 보존 기간은 CloudWatch Logs가 지원하는 양의 보존 일수여야 합니다."                                                                                           # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                             # 설정 묶음 끝
}                                                                                                                                                               # 설정 묶음 끝

variable "route53_role_arn" {                            # 입력 변수: DNS 관리 계정에서 레코드 관리를 허용한 기존 IAM 역할 ARN
  description = "DNS 관리 계정에서 레코드 관리를 허용한 기존 IAM 역할 ARN." # 입력값의 의미와 사용 범위
  type        = string                                   # 입력값의 자료형
  nullable    = false                                    # null 입력 허용 여부

  validation {                                                                                             # 입력값 검증 규칙
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9_+=,.@/-]+$", var.route53_role_arn)) # 허용할 입력값 검증 조건
    error_message = "Route 53 역할은 arn:aws:iam::<12자리 계정 ID>:role/<역할 이름> 형식이어야 합니다."                       # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                        # 설정 묶음 끝
}                                                                                                          # 설정 묶음 끝

variable "route53_zone_id" {                                 # 입력 변수: 서비스 DNS 레코드를 생성할 기존 공개 Route 53 호스팅 영역 ID
  description = "서비스 DNS 레코드를 생성할 기존 공개 Route 53 호스팅 영역 ID." # 입력값의 의미와 사용 범위
  type        = string                                       # 입력값의 자료형
  nullable    = false                                        # null 입력 허용 여부

  validation {                                                                # 입력값 검증 규칙
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))           # 허용할 입력값 검증 조건
    error_message = "호스팅 영역 ID는 /hostedzone/ 접두사 없이 Z로 시작하는 영문 대문자·숫자여야 합니다." # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                           # 설정 묶음 끝
}                                                                             # 설정 묶음 끝
variable "db_password" {                                                      # 입력 변수: 기존 RDS 비밀번호
  description = "기존 RDS 비밀번호. Secrets Manager 쓰기에만 사용하며 상태에 저장하지 않습니다."       # 입력값의 의미와 사용 범위
  type        = string                                                        # 입력값의 자료형
  sensitive   = true                                                          # CLI 출력에서 입력값을 숨기도록 지정
  ephemeral   = true                                                          # 입력값을 상태·계획 파일에 저장하지 않도록 지정
  nullable    = false                                                         # null 입력 허용 여부

  validation {                                                    # 입력값 검증 규칙
    condition     = can(regex("^[ -~]{8,128}$", var.db_password)) # 허용할 입력값 검증 조건
    error_message = "기존 RDS 비밀번호는 줄바꿈 없는 8~128자 ASCII 값이어야 합니다."  # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                               # 설정 묶음 끝
}                                                                 # 설정 묶음 끝
