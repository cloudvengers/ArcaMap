module "buckets" {                                  # 웹 콘텐츠 S3 모듈 연결
  for_each = {                                      # 대상 항목별로 블록 반복
    static = {                                      # 웹 정적 파일 버킷 설정
      bucket_prefix             = "arcamap-static-" # 고유 접미사를 붙일 버킷 이름 접두사
      expiration_days           = null              # 현재 객체 보존 기간(일)
      noncurrent_retention_days = 7
    }                                                                 # 설정 묶음 끝
    photos = {                                                        # 사진 버킷 설정
      bucket_prefix             = "arcamap-photos-"                   # 고유 접미사를 붙일 버킷 이름 접두사
      expiration_days           = null                                # 현재 객체 보존 기간(일)
      noncurrent_retention_days = var.photo_noncurrent_retention_days # 이전 객체 버전 보존 기간(일)
    }                                                                 # 설정 묶음 끝
    cloudfront_logs = {                                               # CloudFront 접근 로그 저장용 버킷 설정
      bucket_prefix             = "arcamap-cloudfront-logs-"          # 고유 접미사를 붙일 버킷 이름 접두사
      expiration_days           = var.log_retention_days              # 현재 객체 보존 기간(일)
      noncurrent_retention_days = 7
    }                                # 설정 묶음 끝
  }                                  # 설정 묶음 끝
  source = "../../modules/s3-bucket" # 로컬 하위 모듈 경로

  bucket_prefix             = each.value.bucket_prefix             # 고유 접미사를 붙일 버킷 이름 접두사
  expiration_days           = each.value.expiration_days           # 현재 객체 보존 기간(일)
  noncurrent_retention_days = each.value.noncurrent_retention_days # 이전 객체 버전 보존 기간(일)
}                                                                  # 설정 묶음 끝

# 실제 기존 설정을 먼저 import하며 객체를 복사하거나 삭제하지 않습니다.
resource "aws_s3_bucket" "maps" {
  bucket        = "protomaps-565725315772-ap-northeast-2-an"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "maps" {
  bucket                  = aws_s3_bucket.maps.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "maps" {
  bucket = aws_s3_bucket.maps.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "maps" {
  bucket = aws_s3_bucket.maps.id

  rule {
    bucket_key_enabled       = true
    blocked_encryption_types = ["SSE-C"]
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "maps" {
  bucket = aws_s3_bucket.maps.id

  cors_rule {
    id              = "LocalProtomapsRead"
    allowed_headers = ["Range", "If-Match", "If-None-Match"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["http://localhost:5173", "http://127.0.0.1:5173", "http://localhost:4173", "http://127.0.0.1:4173"]
    expose_headers  = ["ETag", "Accept-Ranges", "Content-Range", "Content-Length"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_versioning" "maps" {
  bucket = aws_s3_bucket.maps.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 2026-10-02 읽기 조회: NoSuchLifecycleConfiguration. 적용 전에 재확인하고
# 기존 규칙이 생겼다면 이 단일 구성에 통합해야 전체 덮어쓰기로 인한 유실을 막습니다.
resource "aws_s3_bucket_lifecycle_configuration" "maps" {
  bucket = aws_s3_bucket.maps.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.maps]
}
