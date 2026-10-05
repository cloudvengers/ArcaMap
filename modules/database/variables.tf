variable "dsql_endpoint_security_group_id" {
  description = "API·Image Builder에서 TCP 5432 접속을 허용하는 DSQL Endpoint 보안 그룹 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.dsql_endpoint_security_group_id))
    error_message = "Endpoint 보안 그룹 ID는 sg- 뒤에 8자리 또는 17자리 16진수여야 합니다."
  }
}

variable "endpoint_subnet_id" {
  description = "운영 API·Image Builder와 공유하는 서울 운영 AZ의 프라이빗 서브넷 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", var.endpoint_subnet_id))
    error_message = "Endpoint 서브넷 ID는 subnet- 뒤에 8자리 또는 17자리 16진수여야 합니다."
  }
}

variable "vpc_id" {
  description = "Private DNS의 DNS 지원·호스트 이름을 활성화한 공통 VPC ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id))
    error_message = "VPC ID는 vpc- 뒤에 8자리 또는 17자리 16진수여야 합니다."
  }
}
