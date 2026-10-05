output "bucket" {                                                                # bucket 정보를 호출자에게 반환
  description = "버킷 정책과 CloudFront 오리진에 전달할 버킷 식별 정보."                           # 반환하는 값의 의미
  value = {                                                                      # 호출자에게 전달할 값
    id                          = aws_s3_bucket.main.id                          # 호출자에게 전달할 리소스 ID
    arn                         = aws_s3_bucket.main.arn                         # 리소스 ARN
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name # 리전별 S3 오리진 도메인
  }                                                                              # 설정 묶음 끝

  # 오리진 연결과 로그 전달 전에 버킷의 접근·암호화 설정을 완료합니다.
  depends_on = [                                             # 참조만으로 표현되지 않는 선행 작업 지정
    aws_s3_bucket_public_access_block.main,                  # 버킷 반환 전에 공개 접근 차단 설정 완료
    aws_s3_bucket_ownership_controls.main,                   # 버킷 반환 전에 객체 소유권 설정 완료
    aws_s3_bucket_server_side_encryption_configuration.main, # 버킷 반환 전에 기본 암호화 설정 완료
    aws_s3_bucket_versioning.main,
    aws_s3_bucket_lifecycle_configuration.main,
  ] # 설정 묶음 끝
}   # 설정 묶음 끝
