locals {                              # 이 모듈에서 공유할 로컬 값
  map_object_key = "20260907.pmtiles" # CloudFront가 읽을 지도 데이터 객체 키
}                                     # 설정 묶음 끝

resource "aws_cloudfront_origin_access_control" "s3" { # CloudFront 오리진 접근 제어 정의
  name                              = "arcamap-s3"     # AWS 리소스·규칙·작업 이름
  origin_access_control_origin_type = "s3"             # 접근 제어를 적용할 오리진 종류
  signing_behavior                  = "always"         # 오리진 요청 서명 적용 방식
  signing_protocol                  = "sigv4"          # S3 오리진 요청 서명 프로토콜
}                                                      # 설정 묶음 끝

resource "aws_cloudfront_distribution" "site" {    # CloudFront 배포 정의
  enabled             = true                       # EC2 상세 모니터링 사용 여부
  default_root_object = "index.html"               # 기본 요청에 제공할 오리진 객체
  aliases             = [var.frontend_domain_name] # CloudFront에 연결할 도메인 이름
  http_version        = "http2and3"                # CloudFront가 지원할 HTTP 버전
  is_ipv6_enabled     = true                       # CloudFront IPv6 지원 여부
  price_class         = var.cloudfront_price_class # CloudFront 엣지 위치 가격 등급
  wait_for_deployment = true                       # CloudFront 배포 완료 대기 여부
  web_acl_id          = aws_wafv2_web_acl.site.arn # CloudFront에 연결할 WAF 웹 ACL ARN

  origin {                                                                           # S3 오리진 연결
    origin_id                = "static"                                              # CloudFront 내부 오리진 식별자
    domain_name              = var.origin_buckets.static.bucket_regional_domain_name # 오리진 또는 인증서 도메인
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id            # S3 오리진 접근 제어 ID
    connection_attempts      = 3                                                     # 오리진 연결 시도 횟수
    connection_timeout       = 10                                                    # 오리진 연결 제한 시간(초)
  }                                                                                  # 설정 묶음 끝

  origin {                                                                           # S3 오리진 연결
    origin_id                = "photos"                                              # CloudFront 내부 오리진 식별자
    domain_name              = var.origin_buckets.photos.bucket_regional_domain_name # 오리진 또는 인증서 도메인
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id            # S3 오리진 접근 제어 ID
    connection_attempts      = 3                                                     # 오리진 연결 시도 횟수
    connection_timeout       = 10                                                    # 오리진 연결 제한 시간(초)
  }                                                                                  # 설정 묶음 끝

  origin {                                                                         # S3 오리진 연결
    origin_id                = "maps"                                              # CloudFront 내부 오리진 식별자
    domain_name              = var.origin_buckets.maps.bucket_regional_domain_name # 오리진 또는 인증서 도메인
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id          # S3 오리진 접근 제어 ID
    connection_attempts      = 3                                                   # 오리진 연결 시도 횟수
    connection_timeout       = 10                                                  # 오리진 연결 제한 시간(초)
  }                                                                                # 설정 묶음 끝

  default_cache_behavior {                                           # 기본 콘텐츠 요청 처리
    target_origin_id       = "static"                                # 요청을 전달할 CloudFront 오리진 ID
    cache_policy_id        = aws_cloudfront_cache_policy.frontend.id # 요청에 적용할 CloudFront 캐시 정책 ID
    allowed_methods        = ["GET", "HEAD"]                         # 오리진으로 전달할 HTTP 메서드
    cached_methods         = ["GET", "HEAD"]                         # 응답을 캐시할 HTTP 메서드
    viewer_protocol_policy = "redirect-to-https"                     # 클라이언트 HTTP·HTTPS 요청 처리 방식
    compress               = true                                    # CloudFront 응답 압축 여부
  }                                                                  # 설정 묶음 끝

  ordered_cache_behavior {                                        # 경로별 콘텐츠 요청 처리
    path_pattern           = "/photos/*"                          # 캐시 동작을 선택할 요청 경로 패턴
    target_origin_id       = "photos"                             # 요청을 전달할 CloudFront 오리진 ID
    cache_policy_id        = aws_cloudfront_cache_policy.media.id # 요청에 적용할 CloudFront 캐시 정책 ID
    allowed_methods        = ["GET", "HEAD"]                      # 오리진으로 전달할 HTTP 메서드
    cached_methods         = ["GET", "HEAD"]                      # 응답을 캐시할 HTTP 메서드
    viewer_protocol_policy = "redirect-to-https"                  # 클라이언트 HTTP·HTTPS 요청 처리 방식
    compress               = false                                # CloudFront 응답 압축 여부
  }                                                               # 설정 묶음 끝

  ordered_cache_behavior {                                        # 경로별 콘텐츠 요청 처리
    path_pattern           = "/${local.map_object_key}"           # 캐시 동작을 선택할 요청 경로 패턴
    target_origin_id       = "maps"                               # 요청을 전달할 CloudFront 오리진 ID
    cache_policy_id        = aws_cloudfront_cache_policy.media.id # 요청에 적용할 CloudFront 캐시 정책 ID
    allowed_methods        = ["GET", "HEAD"]                      # 오리진으로 전달할 HTTP 메서드
    cached_methods         = ["GET", "HEAD"]                      # 응답을 캐시할 HTTP 메서드
    viewer_protocol_policy = "redirect-to-https"                  # 클라이언트 HTTP·HTTPS 요청 처리 방식
    compress               = false                                # CloudFront 응답 압축 여부
  }                                                               # 설정 묶음 끝

  restrictions {                # 콘텐츠 접근 제한
    geo_restriction {           # 국가별 콘텐츠 접근 제한
      restriction_type = "none" # CloudFront 지리적 접근 제한 방식
      locations        = []     # 지리적 접근 제한 대상 국가 목록
    }                           # 설정 묶음 끝
  }                             # 설정 묶음 끝

  viewer_certificate {                             # 클라이언트 HTTPS 인증서 설정
    acm_certificate_arn      = var.certificate_arn # HTTPS에 사용할 ACM 인증서 ARN
    ssl_support_method       = "sni-only"          # CloudFront TLS 인증서 제공 방식
    minimum_protocol_version = "TLSv1.2_2025"      # 클라이언트 TLS 보안 정책
  }                                                # 설정 묶음 끝
}                                                  # 설정 묶음 끝
