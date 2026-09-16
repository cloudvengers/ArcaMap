variable "vpc_id" {
  description = "보안 그룹을 생성할 VPC ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id))
    error_message = "vpc_id는 유효한 VPC ID여야 합니다."
  }
}
