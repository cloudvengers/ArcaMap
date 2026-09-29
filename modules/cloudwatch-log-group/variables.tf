variable "log_retention_days" {                       # 입력 변수: CloudWatch와 CloudFront 로그 보존 기간(일)
  description = "CloudWatch와 CloudFront 로그 보존 기간(일)." # 입력값의 의미와 사용 범위
  type        = number                                # 입력값의 자료형
  nullable    = false                                 # null 입력 허용 여부

  validation {                                                                                                                                                  # 입력값 검증 규칙
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days) # 허용할 입력값 검증 조건
    error_message = "로그 보존 기간은 CloudWatch Logs가 지원하는 양의 보존 일수여야 합니다."                                                                                           # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                             # 설정 묶음 끝
}                                                                                                                                                               # 설정 묶음 끝

variable "name" {                          # 입력 변수: CloudWatch 로그 그룹의 전체 이름
  description = "CloudWatch 로그 그룹의 전체 이름." # 입력값의 의미와 사용 범위
  type        = string                     # 입력값의 자료형
  nullable    = false                      # null 입력 허용 여부

  validation {                                                                                         # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9/._#-]{1,512}$", var.name)) && !startswith(var.name, "aws/") # 허용할 입력값 검증 조건
    error_message = "로그 그룹 이름은 1~512자의 영숫자·/._#-로 지정하며 aws/로 시작할 수 없습니다."                              # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                    # 설정 묶음 끝
}                                                                                                      # 설정 묶음 끝
