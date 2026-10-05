resource "aws_s3_bucket" "main" {      # S3 버킷 정의
  bucket_prefix    = var.bucket_prefix # 고유 접미사를 붙일 버킷 이름 접두사
  bucket_namespace = "global"          # S3 버킷 이름의 네임스페이스
  force_destroy    = false             # 버킷 삭제 시 남은 객체 강제 삭제 여부
}                                      # 설정 묶음 끝

resource "aws_s3_bucket_public_access_block" "main" { # S3 공개 접근 차단 정의
  bucket                  = aws_s3_bucket.main.id     # 대상 S3 버킷 이름 또는 ID
  block_public_acls       = true                      # 공개 ACL 생성 차단 여부
  block_public_policy     = true                      # 공개 버킷 정책 생성 차단 여부
  ignore_public_acls      = true                      # 기존 공개 ACL 무시 여부
  restrict_public_buckets = true                      # 공개 정책 버킷의 외부 접근 제한 여부
}                                                     # 설정 묶음 끝

resource "aws_s3_bucket_ownership_controls" "main" { # S3 객체 소유권 정의
  bucket = aws_s3_bucket.main.id                     # 대상 S3 버킷 이름 또는 ID

  rule {                                     # 접근 검사 또는 객체 수명 주기 규칙
    object_ownership = "BucketOwnerEnforced" # S3 객체 소유권과 ACL 사용 방식
  }                                          # 설정 묶음 끝
}                                            # 설정 묶음 끝

resource "aws_s3_bucket_server_side_encryption_configuration" "main" { # S3 기본 암호화 정의
  bucket = aws_s3_bucket.main.id                                       # 대상 S3 버킷 이름 또는 ID

  rule {                                      # 접근 검사 또는 객체 수명 주기 규칙
    apply_server_side_encryption_by_default { # 기본 서버 측 암호화 설정
      sse_algorithm = "AES256"                # S3 기본 서버 측 암호화 알고리즘
    }                                         # 설정 묶음 끝
  }                                           # 설정 묶음 끝
}                                             # 설정 묶음 끝

resource "aws_s3_bucket_versioning" "main" { # S3 버전 관리 정의
  bucket = aws_s3_bucket.main.id             # 대상 S3 버킷 이름 또는 ID

  versioning_configuration { # S3 버전 관리 설정
    status = "Enabled"       # S3 버전 관리·수명 주기 활성화 상태
  }                          # 설정 묶음 끝
}                            # 설정 묶음 끝

resource "aws_s3_bucket_lifecycle_configuration" "main" { # S3 객체 수명 주기 정의
  bucket = aws_s3_bucket.main.id                          # 대상 S3 버킷 이름 또는 ID

  rule {
    id     = "expire-noncurrent-versions" # 객체 정리 규칙 식별자
    status = "Enabled"                    # S3 버전 관리·수명 주기 활성화 상태

    filter {} # 조회 대상 또는 객체 수명 주기 필터

    noncurrent_version_expiration { # 이전 객체 버전 만료 설정
      noncurrent_days = var.noncurrent_retention_days
    } # 설정 묶음 끝

    expiration {                          # 객체·삭제 마커 정리 설정
      expired_object_delete_marker = true # 객체가 없는 삭제 마커 정리 여부
    }                                     # 설정 묶음 끝
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  } # 설정 묶음 끝

  dynamic "rule" {                                                      # 입력값에 따른 동적 규칙 생성
    for_each = var.expiration_days == null ? [] : [var.expiration_days] # 대상 항목별로 블록 반복

    content {                           # 동적으로 생성할 규칙 본문
      id     = "expire-cloudfront-logs" # 객체 정리 규칙 식별자
      status = "Enabled"                # S3 버전 관리·수명 주기 활성화 상태

      filter {} # 조회 대상 또는 객체 수명 주기 필터

      expiration {        # 객체·삭제 마커 정리 설정
        days = rule.value # 현재 객체를 만료할 경과 일수
      }                   # 설정 묶음 끝
    }                     # 설정 묶음 끝
  }                       # 설정 묶음 끝

  depends_on = [aws_s3_bucket_versioning.main] # 참조만으로 표현되지 않는 선행 작업 지정
}                                              # 설정 묶음 끝
