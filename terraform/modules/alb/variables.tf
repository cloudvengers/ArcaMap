variable "alb_security_group_id" {
  description = "app에서 생성한 ALB 보안 그룹 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.alb_security_group_id))
    error_message = "alb_security_group_id는 유효한 sg ID여야 합니다."
  }
}

variable "certificate_arn" {
  description = "API 도메인에 발급된 서울 리전 ACM 인증서 ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:acm:ap-northeast-2:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "ALB 인증서는 ap-northeast-2 ACM 인증서 ARN이어야 합니다."
  }
}

variable "log_group_arn" {
  description = "ALB 접근·연결·상태 검사 로그를 전달할 CloudWatch 로그 그룹 ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:logs:ap-northeast-2:[0-9]{12}:log-group:", var.log_group_arn))
    error_message = "서울 리전 CloudWatch 로그 그룹 ARN을 지정해야 합니다."
  }
}

variable "public_subnet_ids" {
  description = "서로 다른 AZ에 있는 두 공개 서브넷 ID."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.public_subnet_ids) == 2 && length(distinct(var.public_subnet_ids)) == 2 && alltrue([for id in var.public_subnet_ids : can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "public_subnet_ids는 서로 다른 유효한 서브넷 ID 두 개여야 합니다."
  }
}

variable "vpc_id" {
  description = "app에서 생성한 VPC ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id))
    error_message = "vpc_id는 유효한 vpc ID여야 합니다."
  }
}
