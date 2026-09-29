module "buckets" {                                                    # 웹 콘텐츠 S3 모듈 연결
  for_each = {                                                        # 대상 항목별로 블록 반복
    static = {                                                        # 웹 정적 파일 버킷 설정
      bucket_prefix             = "arcamap-static-"                   # 고유 접미사를 붙일 버킷 이름 접두사
      expiration_days           = null                                # 현재 객체 보존 기간(일)
      noncurrent_retention_days = null                                # 이전 객체 버전 보존 기간(일)
    }                                                                 # 설정 묶음 끝
    photos = {                                                        # 사진 버킷 설정
      bucket_prefix             = "arcamap-photos-"                   # 고유 접미사를 붙일 버킷 이름 접두사
      expiration_days           = null                                # 현재 객체 보존 기간(일)
      noncurrent_retention_days = var.photo_noncurrent_retention_days # 이전 객체 버전 보존 기간(일)
    }                                                                 # 설정 묶음 끝
    cloudfront_logs = {                                               # CloudFront 접근 로그 저장용 버킷 설정
      bucket_prefix             = "arcamap-cloudfront-logs-"          # 고유 접미사를 붙일 버킷 이름 접두사
      expiration_days           = var.log_retention_days              # 현재 객체 보존 기간(일)
      noncurrent_retention_days = null                                # 이전 객체 버전 보존 기간(일)
    }                                                                 # 설정 묶음 끝
  }                                                                   # 설정 묶음 끝
  source = "../../modules/s3-bucket"                                  # 로컬 하위 모듈 경로

  bucket_prefix             = each.value.bucket_prefix             # 고유 접미사를 붙일 버킷 이름 접두사
  expiration_days           = each.value.expiration_days           # 현재 객체 보존 기간(일)
  noncurrent_retention_days = each.value.noncurrent_retention_days # 이전 객체 버전 보존 기간(일)
}                                                                  # 설정 묶음 끝
