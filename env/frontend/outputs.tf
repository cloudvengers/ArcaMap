output "cloudfront" {                           # cloudfront 정보를 호출자에게 반환
  description = "CloudFront 배포 식별자와 DNS 연결 대상." # 반환하는 값의 의미
  value       = module.cloudfront.cloudfront    # 호출자에게 전달할 값
}                                               # 설정 묶음 끝

output "frontend_url" {                               # frontend_url 정보를 호출자에게 반환
  description = "DNS 연결 후 사용할 프런트엔드 HTTPS 주소."        # 반환하는 값의 의미
  value       = "https://${var.frontend_domain_name}" # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "s3_buckets" {
  description = "정적 파일·사진·CloudFront 로그·기존 지도 버킷 이름."
  value       = tomap(merge({ for name, bucket in module.buckets : name => bucket.bucket.id }, { maps = aws_s3_bucket.maps.id }))
}

output "s3_bucket_arns" {
  description = "백업과 API IAM에 전달할 static/photos/cloudfront_logs/maps 버킷 ARN."
  value       = tomap(merge({ for name, bucket in module.buckets : name => bucket.bucket.arn }, { maps = aws_s3_bucket.maps.arn }))
  depends_on  = [aws_s3_bucket_versioning.maps]
}
