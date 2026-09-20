variable "api_security_group_id" {
  description = "app에서 생성한 API 보안 그룹 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.api_security_group_id))
    error_message = "api_security_group_id는 유효한 sg ID여야 합니다."
  }
}

variable "api_subnet_ids" {
  description = "서로 다른 AZ에 있는 두 API 사설 서브넷 ID."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.api_subnet_ids) == 2 && length(distinct(var.api_subnet_ids)) == 2 && alltrue([for id in var.api_subnet_ids : can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "api_subnet_ids는 서로 다른 유효한 서브넷 ID 두 개여야 합니다."
  }
}

variable "asg_cpu_target" {
  description = "Auto Scaling 목표 CPU 사용률(%)."
  type        = number
  nullable    = false

  validation {
    condition     = var.asg_cpu_target > 0 && var.asg_cpu_target <= 100
    error_message = "CPU 목표 사용률은 0보다 크고 100 이하여야 합니다."
  }
}

variable "asg_health_check_type" {
  description = "Auto Scaling의 고장 판단 기준. 초기 배포는 EC2, API 설치·응답 확인 후 ELB로 전환합니다."
  type        = string
  default     = "EC2"
  nullable    = false

  validation {
    condition     = contains(["EC2", "ELB"], var.asg_health_check_type)
    error_message = "상태 검사 유형은 EC2 또는 ELB여야 합니다."
  }
}

variable "asg_max_size" {
  description = "Auto Scaling 그룹의 최대 EC2 대수."
  type        = number
  nullable    = false

  validation {
    condition     = var.asg_max_size >= 2 && floor(var.asg_max_size) == var.asg_max_size
    error_message = "ASG 최대 대수는 고정 최소 대수인 2 이상의 정수여야 합니다."
  }
}

variable "cloudwatch_agent_start" {
  description = "WAS 루트에서 Image Builder와 운영 EC2에 공통으로 전달하는 CloudWatch Agent 시작 명령."
  type        = string
  nullable    = false
}

variable "ec2_instance_profile_name" {
  description = "WAS 루트에서 생성해 전달하는 운영 API EC2 인스턴스 프로파일 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,128}$", var.ec2_instance_profile_name))
    error_message = "인스턴스 프로파일 이름은 1~128자의 영숫자 또는 _+=,.@- 문자만 사용할 수 있습니다."
  }
}

variable "ec2_instance_type" {
  description = "운영 API EC2 인스턴스 유형."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.ec2_instance_type))
    error_message = "인스턴스 유형은 공백 없는 t3.small 등의 형식이어야 합니다."
  }
}

variable "ec2_root_volume_size" {
  description = "운영 EC2 루트 EBS 용량(GiB)."
  type        = number
  nullable    = false

  validation {
    condition     = var.ec2_root_volume_size >= 20 && floor(var.ec2_root_volume_size) == var.ec2_root_volume_size && var.ec2_root_volume_size >= var.image.root_volume_size
    error_message = "운영 루트 EBS 용량은 20GiB 이상의 정수이며 빌드 루트 용량 이상이어야 합니다."
  }
}

variable "image" {
  description = "Image Builder의 AMI ID·루트 장치 이름·루트 볼륨 용량."
  type = object({
    id               = string
    root_device_name = string
    root_volume_size = number
  })
  nullable = false

  validation {
    condition = (
      can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.image.id)) &&
      can(regex("^/dev/[A-Za-z0-9]+$", var.image.root_device_name)) &&
      var.image.root_volume_size >= 20 && floor(var.image.root_volume_size) == var.image.root_volume_size
    )
    error_message = "유효한 AMI ID·/dev/ 장치 이름과 20GiB 이상의 정수 루트 볼륨 용량을 지정해야 합니다."
  }
}

variable "target_group_arn" {
  description = "HTTPS 리스너 연결이 완료된 ALB API 대상 그룹 ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:elasticloadbalancing:ap-northeast-2:[0-9]{12}:targetgroup/[^/]+/[0-9a-f]+$", var.target_group_arn))
    error_message = "서울 리전 ALB 대상 그룹 ARN을 지정해야 합니다."
  }
}
