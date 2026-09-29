module "cloudfront" {                 # 콘텐츠 CDN·WAF 모듈 연결
  source = "../../modules/cloudfront" # 로컬 하위 모듈 경로

  account_id                 = data.aws_caller_identity.current.account_id              # CloudFront 로그 전달 대상 계정 ID
  certificate_arn            = data.aws_acm_certificate.site.arn                        # TLS 인증서 ARN
  frontend_domain_name       = var.frontend_domain_name                                 # 웹 화면의 DNS 호스트 이름
  frontend_cache_ttl_seconds = var.frontend_cache_ttl_seconds                           # 웹 화면 캐시 유지 시간(초)
  media_cache_ttl_seconds    = var.media_cache_ttl_seconds                              # 지도·사진 캐시 유지 시간(초)
  cloudfront_price_class     = var.cloudfront_price_class                               # CloudFront 엣지 위치 가격 등급
  logs_bucket                = module.buckets["cloudfront_logs"].bucket                 # CloudFront 접근 로그 버킷 정보
  origin_buckets = {                                                                    # 웹·사진·지도 오리진 버킷 정보
    static = module.buckets["static"].bucket                                            # 웹 정적 파일 버킷 설정
    photos = module.buckets["photos"].bucket                                            # 사진 버킷 설정
    maps = {                                                                            # 기존 지도 버킷의 오리진 정보
      id                          = data.aws_s3_bucket.maps.id                          # 호출자에게 전달할 리소스 ID
      arn                         = data.aws_s3_bucket.maps.arn                         # 리소스 ARN
      bucket_regional_domain_name = data.aws_s3_bucket.maps.bucket_regional_domain_name # 리전별 S3 오리진 도메인
    }                                                                                   # 설정 묶음 끝
  }                                                                                     # 설정 묶음 끝
}                                                                                       # 설정 묶음 끝
