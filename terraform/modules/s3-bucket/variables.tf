variable "bucket_prefix" {
  description = "Terraform이 고유 접미사를 붙이기 전의 버킷 이름 접두사."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*-$", var.bucket_prefix))
    error_message = "버킷 접두사는 소문자·숫자로 시작하고 소문자·숫자·하이픈을 사용하며 하이픈으로 끝나야 합니다."
  }
}

variable "expiration_days" {
  description = "현재 객체 만료 일수. null이면 현재 객체 만료 규칙을 만들지 않습니다."
  type        = number
  default     = null

  validation {
    condition     = var.expiration_days == null ? true : var.expiration_days >= 1 && floor(var.expiration_days) == var.expiration_days
    error_message = "현재 객체 만료 일수는 null 또는 양의 정수여야 합니다."
  }
}

variable "noncurrent_retention_days" {
  description = "이전 버전 보존 일수. 값이 있으면 버전 관리와 삭제 마커 정리도 활성화합니다."
  type        = number
  default     = null

  validation {
    condition     = var.noncurrent_retention_days == null ? true : var.noncurrent_retention_days >= 1 && floor(var.noncurrent_retention_days) == var.noncurrent_retention_days
    error_message = "이전 버전 보존 일수는 null 또는 양의 정수여야 합니다."
  }
}
