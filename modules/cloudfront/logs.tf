resource "aws_cloudwatch_log_delivery_source" "cloudfront" { # 로그 전달 소스 정의
  region       = "us-east-1"                                 # 리소스 생성·조회 또는 지표 표시 리전
  name         = "arcamap-cloudfront"                        # AWS 리소스·규칙·작업 이름
  log_type     = "ACCESS_LOGS"                               # 전달할 로그 종류
  resource_arn = aws_cloudfront_distribution.site.arn        # 로그 기록 또는 WAF 보호 대상 ARN
}                                                            # 설정 묶음 끝

resource "aws_cloudwatch_log_delivery_destination" "cloudfront" { # 로그 전달 대상 정의
  region        = "us-east-1"                                     # 리소스 생성·조회 또는 지표 표시 리전
  name          = "arcamap-cloudfront"                            # AWS 리소스·규칙·작업 이름
  output_format = "json"                                          # 전달할 로그의 출력 형식

  delivery_destination_configuration {             # 로그를 저장할 리소스 연결
    destination_resource_arn = var.logs_bucket.arn # 로그를 저장할 버킷·로그 그룹 ARN
  }                                                # 설정 묶음 끝
}                                                  # 설정 묶음 끝

resource "aws_cloudwatch_log_delivery" "cloudfront" {                               # 로그 전달 연결 정의
  region                   = "us-east-1"                                            # 리소스 생성·조회 또는 지표 표시 리전
  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront.name     # 연결할 로그 전달 소스 이름
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront.arn # 로그 전달 대상 ARN

  depends_on = [aws_s3_bucket_policy.cloudfront_logs] # 참조만으로 표현되지 않는 선행 작업 지정
}                                                     # 설정 묶음 끝

resource "aws_s3_bucket_policy" "cloudfront_logs" {                               # S3 버킷 정책 정의
  bucket = var.logs_bucket.id                                                     # 대상 S3 버킷 이름 또는 ID
  policy = jsonencode({                                                           # 접근 권한 정책을 JSON으로 변환
    Version = "2012-10-17"                                                        # IAM 정책 문서 버전
    Statement = [{                                                                # IAM 정책의 권한 문장 목록
      Sid       = "AWSLogsDeliveryWrite"                                          # 권한 문장 식별자
      Effect    = "Allow"                                                         # 권한 허용 또는 거부 동작
      Principal = { Service = "delivery.logs.amazonaws.com" }                     # 이 정책을 적용할 접근 주체
      Action    = "s3:PutObject"                                                  # 허용하거나 거부할 AWS 작업
      Resource  = "${var.logs_bucket.arn}/AWSLogs/${var.account_id}/CloudFront/*" # 권한을 적용할 리소스 ARN
      Condition = {                                                               # 정책을 적용할 추가 조건
        StringEquals = {                                                          # 문자열이 같아야 하는 조건
          "aws:SourceAccount" = var.account_id                                    # 로그 전달을 허용할 AWS 계정
          "s3:x-amz-acl"      = "bucket-owner-full-control"                       # 로그 객체의 소유권 ACL 조건
        }                                                                         # 설정 묶음 끝
        ArnLike = {                                                               # ARN 패턴 일치 조건
          "aws:SourceArn" = aws_cloudwatch_log_delivery_source.cloudfront.arn     # 접근을 허용할 로그 전달 소스 ARN
        }                                                                         # 설정 묶음 끝
      }                                                                           # 설정 묶음 끝
      }, {
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [var.logs_bucket.arn, "${var.logs_bucket.arn}/*"]
      Condition = {
        Bool = {
          "aws:SecureTransport"       = "false"
          "aws:PrincipalIsAWSService" = "false"
        }
      }
    }]
  }) # 설정 묶음 끝
}    # 설정 묶음 끝

resource "aws_cloudwatch_log_group" "waf" {                                                        # CloudWatch 기본 암호화로 WAF 요청 로그 저장
  name              = "aws-waf-logs-CloudFrontDistribution-${aws_cloudfront_distribution.site.id}" # WAF 로그 전용 접두사 사용
  region            = "us-east-1"                                                                  # 웹 ACL과 같은 리전에 로그 저장
  log_group_class   = "STANDARD"                                                                   # 표준 로그 클래스 사용
  retention_in_days = 14                                                                           # 로그를 14일 보관한 뒤 만료
}                                                                                                  # 설정 묶음 끝
