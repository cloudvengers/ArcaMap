# 2026-10-02 지도 버킷 읽기 조회: NoSuchBucketPolicy. 적용 전에 재확인하고
# 기존 정책이 생겼다면 해당 Statement를 이 단일 정책에 보존해야 합니다.
resource "aws_s3_bucket_policy" "origin" { # S3 버킷 정책 정의
  for_each = var.origin_buckets            # 대상 항목별로 블록 반복

  bucket = each.value.id                                                                 # 대상 S3 버킷 이름 또는 ID
  policy = jsonencode({                                                                  # 접근 권한 정책을 JSON으로 변환
    Version = "2012-10-17"                                                               # IAM 정책 문서 버전
    Statement = [{                                                                       # IAM 정책의 권한 문장 목록
      Sid       = "AllowCloudFrontRead"                                                  # 권한 문장 식별자
      Effect    = "Allow"                                                                # 권한 허용 또는 거부 동작
      Principal = { Service = "cloudfront.amazonaws.com" }                               # 이 정책을 적용할 접근 주체
      Action    = "s3:GetObject"                                                         # 허용하거나 거부할 AWS 작업
      Resource  = "${each.value.arn}/${each.key == "maps" ? local.map_object_key : "*"}" # 권한을 적용할 리소스 ARN
      Condition = {                                                                      # 정책을 적용할 추가 조건
        StringEquals = {                                                                 # 문자열이 같아야 하는 조건
          "AWS:SourceArn"     = aws_cloudfront_distribution.site.arn                     # 접근을 허용할 CloudFront 배포 ARN
          "AWS:SourceAccount" = var.account_id
        } # 설정 묶음 끝
      }   # 설정 묶음 끝
      }, {
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [each.value.arn, "${each.value.arn}/*"]
      Condition = {
        Bool = {
          "aws:SecureTransport"       = "false"
          "aws:PrincipalIsAWSService" = "false"
        }
      }
    }]
  }) # 설정 묶음 끝
}    # 설정 묶음 끝
