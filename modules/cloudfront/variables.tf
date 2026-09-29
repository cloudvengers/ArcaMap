variable "account_id" {                          # 입력 변수: CloudFront 로그 전달 대상 AWS 계정 ID
  description = "CloudFront 로그 전달 대상 AWS 계정 ID." # 입력값의 의미와 사용 범위
  type        = string                           # 입력값의 자료형
  nullable    = false                            # null 입력 허용 여부

  validation {                                                # 입력값 검증 규칙
    condition     = can(regex("^[0-9]{12}$", var.account_id)) # 허용할 입력값 검증 조건
    error_message = "AWS 계정 ID는 12자리 숫자여야 합니다."               # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                           # 설정 묶음 끝
}                                                             # 설정 묶음 끝

variable "certificate_arn" {                            # 입력 변수: 프런트엔드 도메인에 발급된 us-east-1 ACM 인증서 ARN
  description = "프런트엔드 도메인에 발급된 us-east-1 ACM 인증서 ARN." # 입력값의 의미와 사용 범위
  type        = string                                  # 입력값의 자료형
  nullable    = false                                   # null 입력 허용 여부

  validation {                                                                                                  # 입력값 검증 규칙
    condition     = can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn)) # 허용할 입력값 검증 조건
    error_message = "CloudFront 인증서는 us-east-1 ACM 인증서 ARN이어야 합니다."                                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                             # 설정 묶음 끝
}                                                                                                               # 설정 묶음 끝

variable "cloudfront_price_class" {        # 입력 변수: CloudFront 엣지 위치의 가격 등급
  description = "CloudFront 엣지 위치의 가격 등급." # 입력값의 의미와 사용 범위
  type        = string                     # 입력값의 자료형
  nullable    = false                      # null 입력 허용 여부

  validation {                                                                                                   # 입력값 검증 규칙
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class) # 허용할 입력값 검증 조건
    error_message = "CloudFront 가격 등급은 PriceClass_100, PriceClass_200, PriceClass_All 중 하나여야 합니다."               # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                              # 설정 묶음 끝
}                                                                                                                # 설정 묶음 끝

variable "frontend_cache_ttl_seconds" {                # 입력 변수: 프런트엔드 CloudFront 캐시의 기본·최대 유지 시간(초)
  description = "프런트엔드 CloudFront 캐시의 기본·최대 유지 시간(초)." # 입력값의 의미와 사용 범위
  type        = number                                 # 입력값의 자료형
  nullable    = false                                  # null 입력 허용 여부

  validation {                                                                                                                     # 입력값 검증 규칙
    condition     = var.frontend_cache_ttl_seconds >= 0 && floor(var.frontend_cache_ttl_seconds) == var.frontend_cache_ttl_seconds # 허용할 입력값 검증 조건
    error_message = "캐시 유지 시간은 0 이상의 정수여야 합니다."                                                                                    # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                # 설정 묶음 끝
}                                                                                                                                  # 설정 묶음 끝

variable "frontend_domain_name" {       # 입력 변수: 정적 프런트엔드의 DNS 호스트 이름
  description = "정적 프런트엔드의 DNS 호스트 이름." # 입력값의 의미와 사용 범위
  type        = string                  # 입력값의 자료형
  nullable    = false                   # null 입력 허용 여부

  validation {                                                                                                                                                                                     # 입력값 검증 규칙
    condition     = length(var.frontend_domain_name) <= 253 && can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.frontend_domain_name)) # 허용할 입력값 검증 조건
    error_message = "도메인은 스킴·포트·경로·공백이 없는 253자 이하 DNS 호스트 이름이어야 하며 프런트엔드와 API 주소는 서로 달라야 합니다."                                                                                                     # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                # 설정 묶음 끝
}                                                                                                                                                                                                  # 설정 묶음 끝

variable "logs_bucket" {                          # 입력 변수: CloudFront 접근 로그를 저장할 버킷 식별 정보
  description = "CloudFront 접근 로그를 저장할 버킷 식별 정보." # 입력값의 의미와 사용 범위
  type = object({                                 # 입력값의 자료형
    id  = string                                  # 호출자에게 전달할 리소스 ID
    arn = string                                  # 리소스 ARN
  })                                              # 설정 묶음 끝
  nullable = false                                # null 입력 허용 여부
}                                                 # 설정 묶음 끝

variable "media_cache_ttl_seconds" {                   # 입력 변수: 지도·사진 CloudFront 캐시의 기본·최대 유지 시간(초)
  description = "지도·사진 CloudFront 캐시의 기본·최대 유지 시간(초)." # 입력값의 의미와 사용 범위
  type        = number                                 # 입력값의 자료형
  nullable    = false                                  # null 입력 허용 여부

  validation {                                                                                                            # 입력값 검증 규칙
    condition     = var.media_cache_ttl_seconds >= 0 && floor(var.media_cache_ttl_seconds) == var.media_cache_ttl_seconds # 허용할 입력값 검증 조건
    error_message = "캐시 유지 시간은 0 이상의 정수여야 합니다."                                                                           # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                       # 설정 묶음 끝
}                                                                                                                         # 설정 묶음 끝

variable "origin_buckets" {                                                                # 입력 변수: static·photos 버킷과 기존 maps 버킷의 식별 정보
  description = "static·photos 버킷과 기존 maps 버킷의 식별 정보. maps 버킷의 생성·수명 주기는 이 모듈이 관리하지 않습니다." # 입력값의 의미와 사용 범위
  type = map(object({                                                                      # 입력값의 자료형
    id                          = string                                                   # 호출자에게 전달할 리소스 ID
    arn                         = string                                                   # 리소스 ARN
    bucket_regional_domain_name = string                                                   # 리전별 S3 오리진 도메인
  }))                                                                                      # 설정 묶음 끝
  nullable = false                                                                         # null 입력 허용 여부

  validation {                                                                             # 입력값 검증 규칙
    condition     = toset(keys(var.origin_buckets)) == toset(["maps", "photos", "static"]) # 허용할 입력값 검증 조건
    error_message = "오리진 버킷은 maps·photos·static 세 키로 전달해야 합니다."                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                        # 설정 묶음 끝
}                                                                                          # 설정 묶음 끝
