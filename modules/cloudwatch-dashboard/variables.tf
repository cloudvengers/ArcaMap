variable "alarm_arns" {                              # 입력 변수: 대시보드에 표시할 기존 CloudWatch 경보 ARN 목록
  description = "대시보드에 표시할 기존 CloudWatch 경보 ARN 목록." # 입력값의 의미와 사용 범위
  type        = list(string)                         # 입력값의 자료형
  nullable    = false                                # null 입력 허용 여부
}                                                    # 설정 묶음 끝

variable "alb_arn_suffix" {                  # 입력 변수: ALB 지표의 LoadBalancer 차원 값
  description = "ALB 지표의 LoadBalancer 차원 값." # 입력값의 의미와 사용 범위
  type        = string                       # 입력값의 자료형
  nullable    = false                        # null 입력 허용 여부
}                                            # 설정 묶음 끝

variable "asg_name" {           # 입력 변수: 모니터링할 ASG 이름
  description = "모니터링할 ASG 이름." # 입력값의 의미와 사용 범위
  type        = string          # 입력값의 자료형
  nullable    = false           # null 입력 허용 여부
}                               # 설정 묶음 끝

variable "dsql_cluster_identifier" {
  description = "지표 차원에 사용할 DSQL 클러스터 ID. 복구 후에는 새 클러스터 ID를 전달합니다."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.dsql_cluster_identifier))
    error_message = "DSQL 클러스터 ID는 ARN이나 엔드포인트가 아닌 영문 소문자·숫자 식별자여야 합니다."
  }
}

variable "log_groups" {                                            # 입력 변수: 조회로 확인한 ALB·시스템·API WAF·CloudFront WAF 로그 그룹 이름
  description = "조회로 확인한 ALB·시스템·API WAF·CloudFront WAF 로그 그룹 이름." # 입력값의 의미와 사용 범위
  type = object({                                                  # 입력값의 자료형
    alb            = string                                        # ALB 로그 그룹 조회·연결 정보
    system         = string                                        # 시스템 로그 조회 정보
    waf_api        = string                                        # API WAF 로그 그룹 조회 정보
    waf_cloudfront = string                                        # CloudFront WAF 로그 그룹 조회 정보
  })                                                               # 설정 묶음 끝
  nullable = false                                                 # null 입력 허용 여부
}                                                                  # 설정 묶음 끝

variable "name" {                        # 입력 변수: 통합 CloudWatch 대시보드 이름
  description = "통합 CloudWatch 대시보드 이름." # 입력값의 의미와 사용 범위
  type        = string                   # 입력값의 자료형
  default     = "arcamap-operations"     # 입력을 생략했을 때 사용할 기본값
  nullable    = false                    # null 입력 허용 여부

  validation {                                                     # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z0-9_-]{1,255}$", var.name)) # 허용할 입력값 검증 조건
    error_message = "대시보드 이름은 영문·숫자·밑줄·하이픈으로 구성된 1~255자여야 합니다."    # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                # 설정 묶음 끝
}                                                                  # 설정 묶음 끝

variable "region" {                      # 입력 변수: API와 ASG가 실행되는 AWS 리전
  description = "API와 ASG가 실행되는 AWS 리전." # 입력값의 의미와 사용 범위
  type        = string                   # 입력값의 자료형
  default     = "ap-northeast-2"         # 입력을 생략했을 때 사용할 기본값
  nullable    = false                    # null 입력 허용 여부
}                                        # 설정 묶음 끝

variable "target_group_arn_suffix" {        # 입력 변수: ALB 지표의 TargetGroup 차원 값
  description = "ALB 지표의 TargetGroup 차원 값." # 입력값의 의미와 사용 범위
  type        = string                      # 입력값의 자료형
  nullable    = false                       # null 입력 허용 여부
}                                           # 설정 묶음 끝

variable "waf_metric_names" {                                                 # 입력 변수: 기존 API·CloudFront Web ACL의 visibility_config.metric_name 값
  description = "기존 API·CloudFront Web ACL의 visibility_config.metric_name 값." # 입력값의 의미와 사용 범위
  type = object({                                                             # 입력값의 자료형
    api        = string                                                       # API 항목 설정
    cloudfront = string                                                       # CloudFront WAF 조회·연결 정보
  })                                                                          # 설정 묶음 끝
  nullable = false                                                            # null 입력 허용 여부
}                                                                             # 설정 묶음 끝
