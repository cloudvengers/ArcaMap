resource "aws_cloudfront_cache_policy" "frontend" { # CloudFront 캐시 정책 정의
  name        = "arcamap-frontend"                  # AWS 리소스·규칙·작업 이름
  min_ttl     = 0                                   # 캐시 최소 유지 시간(초)
  default_ttl = var.frontend_cache_ttl_seconds      # 캐시 기본 유지 시간(초)
  max_ttl     = var.frontend_cache_ttl_seconds      # 캐시 최대 유지 시간(초)

  parameters_in_cache_key_and_forwarded_to_origin { # 캐시 키와 오리진 요청 파라미터 설정
    enable_accept_encoding_gzip   = true            # gzip 인코딩을 캐시 키에 반영할지 여부
    enable_accept_encoding_brotli = true            # Brotli 인코딩을 캐시 키에 반영할지 여부

    cookies_config {           # 쿠키 캐시 키 설정
      cookie_behavior = "none" # 캐시 키에 쿠키를 포함하는 방식
    }                          # 설정 묶음 끝

    headers_config {           # 헤더 캐시 키 설정
      header_behavior = "none" # 캐시 키에 헤더를 포함하는 방식
    }                          # 설정 묶음 끝

    query_strings_config {           # 쿼리 문자열 캐시 키 설정
      query_string_behavior = "none" # 캐시 키에 쿼리 문자열을 포함하는 방식
    }                                # 설정 묶음 끝
  }                                  # 설정 묶음 끝
}                                    # 설정 묶음 끝

resource "aws_cloudfront_cache_policy" "assets" {
  name        = "arcamap-assets"
  min_ttl     = 0
  default_ttl = 31536000
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "arcamap-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    content_security_policy {
      content_security_policy = join(" ", [
        "default-src 'self';",
        "script-src 'self';",
        "style-src 'self';",
        "style-src-attr 'unsafe-inline';",
        "img-src 'self' data: blob: https://protomaps.github.io/basemaps-assets/;",
        "font-src 'self';",
        "connect-src 'self' https://api.arcamap.app https://protomaps.github.io/basemaps-assets/;",
        "worker-src 'self';",
        "object-src 'none';",
        "base-uri 'none';",
        "frame-src 'none';",
        "frame-ancestors 'none';",
        "form-action 'self';",
      ])
      override = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_cache_policy" "media" { # CloudFront 캐시 정책 정의
  name        = "arcamap-media"                  # AWS 리소스·규칙·작업 이름
  min_ttl     = 0                                # 캐시 최소 유지 시간(초)
  default_ttl = var.media_cache_ttl_seconds      # 캐시 기본 유지 시간(초)
  max_ttl     = var.media_cache_ttl_seconds      # 캐시 최대 유지 시간(초)

  parameters_in_cache_key_and_forwarded_to_origin { # 캐시 키와 오리진 요청 파라미터 설정
    enable_accept_encoding_gzip   = false           # gzip 인코딩을 캐시 키에 반영할지 여부
    enable_accept_encoding_brotli = false           # Brotli 인코딩을 캐시 키에 반영할지 여부

    cookies_config {           # 쿠키 캐시 키 설정
      cookie_behavior = "none" # 캐시 키에 쿠키를 포함하는 방식
    }                          # 설정 묶음 끝

    headers_config {           # 헤더 캐시 키 설정
      header_behavior = "none" # 캐시 키에 헤더를 포함하는 방식
    }                          # 설정 묶음 끝

    query_strings_config {           # 쿼리 문자열 캐시 키 설정
      query_string_behavior = "none" # 캐시 키에 쿼리 문자열을 포함하는 방식
    }                                # 설정 묶음 끝
  }                                  # 설정 묶음 끝
}                                    # 설정 묶음 끝
