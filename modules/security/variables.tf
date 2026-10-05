variable "vpc_id" {                  # 입력 변수: 보안 그룹을 생성할 VPC ID
  description = "보안 그룹을 생성할 VPC ID." # 입력값의 의미와 사용 범위
  type        = string               # 입력값의 자료형
  nullable    = false                # null 입력 허용 여부

  validation {                                                                 # 입력값 검증 규칙
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id)) # 허용할 입력값 검증 조건
    error_message = "vpc_id는 유효한 VPC ID여야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                            # 설정 묶음 끝
}                                                                              # 설정 묶음 끝
