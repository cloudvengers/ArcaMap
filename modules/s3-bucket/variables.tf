variable "bucket_prefix" {                             # 입력 변수: Terraform이 고유 접미사를 붙이기 전의 버킷 이름 접두사
  description = "Terraform이 고유 접미사를 붙이기 전의 버킷 이름 접두사." # 입력값의 의미와 사용 범위
  type        = string                                 # 입력값의 자료형
  nullable    = false                                  # null 입력 허용 여부

  validation {                                                             # 입력값 검증 규칙
    condition     = can(regex("^[a-z0-9][a-z0-9-]*-$", var.bucket_prefix)) # 허용할 입력값 검증 조건
    error_message = "버킷 접두사는 소문자·숫자로 시작하고 소문자·숫자·하이픈을 사용하며 하이픈으로 끝나야 합니다." # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                        # 설정 묶음 끝
}                                                                          # 설정 묶음 끝

variable "expiration_days" {                                 # 입력 변수: 현재 객체 만료 일수
  description = "현재 객체 만료 일수. null이면 현재 객체 만료 규칙을 만들지 않습니다." # 입력값의 의미와 사용 범위
  type        = number                                       # 입력값의 자료형
  default     = null                                         # 입력을 생략했을 때 사용할 기본값

  validation {                                                                                                                         # 입력값 검증 규칙
    condition     = var.expiration_days == null ? true : var.expiration_days >= 1 && floor(var.expiration_days) == var.expiration_days # 허용할 입력값 검증 조건
    error_message = "현재 객체 만료 일수는 null 또는 양의 정수여야 합니다."                                                                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                    # 설정 묶음 끝
}                                                                                                                                      # 설정 묶음 끝

variable "noncurrent_retention_days" {                         # 입력 변수: 이전 버전 보존 일수
  description = "이전 버전 보존 일수. 값이 있으면 버전 관리와 삭제 마커 정리도 활성화합니다." # 입력값의 의미와 사용 범위
  type        = number                                         # 입력값의 자료형
  default     = null                                           # 입력을 생략했을 때 사용할 기본값

  validation {                                                                                                                                                                 # 입력값 검증 규칙
    condition     = var.noncurrent_retention_days == null ? true : var.noncurrent_retention_days >= 1 && floor(var.noncurrent_retention_days) == var.noncurrent_retention_days # 허용할 입력값 검증 조건
    error_message = "이전 버전 보존 일수는 null 또는 양의 정수여야 합니다."                                                                                                                        # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                            # 설정 묶음 끝
}                                                                                                                                                                              # 설정 묶음 끝
