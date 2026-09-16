variable "account_id" {
  description = "CloudFront 로그 전달 대상 AWS 계정 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "AWS 계정 ID는 12자리 숫자여야 합니다."
  }
}

variable "certificate_arn" {
  description = "프런트엔드 도메인에 발급된 us-east-1 ACM 인증서 ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "CloudFront 인증서는 us-east-1 ACM 인증서 ARN이어야 합니다."
  }
}

variable "cloudfront_price_class" {
  description = "CloudFront 엣지 위치의 가격 등급."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "CloudFront 가격 등급은 PriceClass_100, PriceClass_200, PriceClass_All 중 하나여야 합니다."
  }
}

variable "frontend_cache_ttl_seconds" {
  description = "프런트엔드 CloudFront 캐시의 기본·최대 유지 시간(초)."
  type        = number
  nullable    = false

  validation {
    condition     = var.frontend_cache_ttl_seconds >= 0 && floor(var.frontend_cache_ttl_seconds) == var.frontend_cache_ttl_seconds
    error_message = "캐시 유지 시간은 0 이상의 정수여야 합니다."
  }
}

variable "frontend_domain_name" {
  description = "정적 프런트엔드의 DNS 호스트 이름."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.frontend_domain_name) <= 253 && can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.frontend_domain_name))
    error_message = "도메인은 스킴·포트·경로·공백이 없는 253자 이하 DNS 호스트 이름이어야 하며 프런트엔드와 API 주소는 서로 달라야 합니다."
  }
}

variable "logs_bucket" {
  description = "CloudFront 접근 로그를 저장할 버킷 식별 정보."
  type = object({
    id  = string
    arn = string
  })
  nullable = false
}

variable "media_cache_ttl_seconds" {
  description = "지도·사진 CloudFront 캐시의 기본·최대 유지 시간(초)."
  type        = number
  nullable    = false

  validation {
    condition     = var.media_cache_ttl_seconds >= 0 && floor(var.media_cache_ttl_seconds) == var.media_cache_ttl_seconds
    error_message = "캐시 유지 시간은 0 이상의 정수여야 합니다."
  }
}

variable "origin_buckets" {
  description = "static·photos 버킷과 기존 maps 버킷의 식별 정보. maps 버킷의 생성·수명 주기는 이 모듈이 관리하지 않습니다."
  type = map(object({
    id                          = string
    arn                         = string
    bucket_regional_domain_name = string
  }))
  nullable = false

  validation {
    condition     = toset(keys(var.origin_buckets)) == toset(["maps", "photos", "static"])
    error_message = "오리진 버킷은 maps·photos·static 세 키로 전달해야 합니다."
  }
}
