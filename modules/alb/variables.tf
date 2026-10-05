variable "alb_security_group_id" {               # 입력 변수: network 루트에서 생성한 ALB 보안 그룹 ID
  description = "network 루트에서 생성한 ALB 보안 그룹 ID." # 입력값의 의미와 사용 범위
  type        = string                           # 입력값의 자료형
  nullable    = false                            # null 입력 허용 여부

  validation {                                                                               # 입력값 검증 규칙
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.alb_security_group_id)) # 허용할 입력값 검증 조건
    error_message = "alb_security_group_id는 유효한 sg ID여야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                          # 설정 묶음 끝
}                                                                                            # 설정 묶음 끝

variable "certificate_arn" {                      # 입력 변수: API 도메인에 발급된 서울 리전 ACM 인증서 ARN
  description = "API 도메인에 발급된 서울 리전 ACM 인증서 ARN." # 입력값의 의미와 사용 범위
  type        = string                            # 입력값의 자료형
  nullable    = false                             # null 입력 허용 여부

  validation {                                                                                                       # 입력값 검증 규칙
    condition     = can(regex("^arn:aws:acm:ap-northeast-2:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn)) # 허용할 입력값 검증 조건
    error_message = "ALB 인증서는 ap-northeast-2 ACM 인증서 ARN이어야 합니다."                                                    # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                  # 설정 묶음 끝
}                                                                                                                    # 설정 묶음 끝

variable "log_group_arn" {                                      # 입력 변수: ALB 접근·연결·상태 검사 로그를 전달할 CloudWatch 로그 그룹 ARN
  description = "ALB 접근·연결·상태 검사 로그를 전달할 CloudWatch 로그 그룹 ARN." # 입력값의 의미와 사용 범위
  type        = string                                          # 입력값의 자료형
  nullable    = false                                           # null 입력 허용 여부

  validation {                                                                                         # 입력값 검증 규칙
    condition     = can(regex("^arn:aws:logs:ap-northeast-2:[0-9]{12}:log-group:", var.log_group_arn)) # 허용할 입력값 검증 조건
    error_message = "서울 리전 CloudWatch 로그 그룹 ARN을 지정해야 합니다."                                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                    # 설정 묶음 끝
}                                                                                                      # 설정 묶음 끝

variable "public_subnet_ids" {              # 입력 변수: 서로 다른 AZ에 있는 두 공개 서브넷 ID
  description = "서로 다른 AZ에 있는 두 공개 서브넷 ID." # 입력값의 의미와 사용 범위
  type        = list(string)                # 입력값의 자료형
  nullable    = false                       # null 입력 허용 여부

  validation {                                                                                                                                                                                               # 입력값 검증 규칙
    condition     = length(var.public_subnet_ids) == 2 && length(distinct(var.public_subnet_ids)) == 2 && alltrue([for id in var.public_subnet_ids : can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", id))]) # 허용할 입력값 검증 조건
    error_message = "public_subnet_ids는 서로 다른 유효한 서브넷 ID 두 개여야 합니다."                                                                                                                                         # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                          # 설정 묶음 끝
}                                                                                                                                                                                                            # 설정 묶음 끝

variable "vpc_id" {                        # 입력 변수: network 루트에서 생성한 VPC ID
  description = "network 루트에서 생성한 VPC ID." # 입력값의 의미와 사용 범위
  type        = string                     # 입력값의 자료형
  nullable    = false                      # null 입력 허용 여부

  validation {                                                                 # 입력값 검증 규칙
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id)) # 허용할 입력값 검증 조건
    error_message = "vpc_id는 유효한 vpc ID여야 합니다."                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                            # 설정 묶음 끝
}                                                                              # 설정 묶음 끝
