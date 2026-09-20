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

variable "log_retention_days" {
  description = "CloudWatch와 CloudFront 로그 보존 기간(일)."
  type        = number
  nullable    = false

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "로그 보존 기간은 CloudWatch Logs가 지원하는 양의 보존 일수여야 합니다."
  }
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

variable "photo_noncurrent_retention_days" {
  description = "사진 객체의 이전 버전 보존 기간(일)."
  type        = number
  nullable    = false

  validation {
    condition     = var.photo_noncurrent_retention_days >= 1 && floor(var.photo_noncurrent_retention_days) == var.photo_noncurrent_retention_days
    error_message = "사진 이전 버전 보존 기간은 양의 정수여야 합니다."
  }
}

variable "route53_role_arn" {
  description = "DNS 관리 계정에서 레코드 관리를 허용한 기존 IAM 역할 ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9_+=,.@/-]+$", var.route53_role_arn))
    error_message = "Route 53 역할은 arn:aws:iam::<12자리 계정 ID>:role/<역할 이름> 형식이어야 합니다."
  }
}

variable "route53_zone_id" {
  description = "서비스 DNS 레코드를 생성할 기존 공개 Route 53 호스팅 영역 ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "호스팅 영역 ID는 /hostedzone/ 접두사 없이 Z로 시작하는 영문 대문자·숫자여야 합니다."
  }
}
