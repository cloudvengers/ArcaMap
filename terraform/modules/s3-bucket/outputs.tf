output "bucket" {
  description = "버킷 정책과 CloudFront 오리진에 전달할 버킷 식별 정보."
  value = {
    id                          = aws_s3_bucket.main.id
    arn                         = aws_s3_bucket.main.arn
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name
  }

  # 오리진 연결과 로그 전달 전에 버킷의 접근·암호화 설정을 완료합니다.
  depends_on = [
    aws_s3_bucket_public_access_block.main,
    aws_s3_bucket_ownership_controls.main,
    aws_s3_bucket_server_side_encryption_configuration.main,
  ]
}
