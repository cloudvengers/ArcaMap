output "cloudfront" {
  description = "CloudFront 배포 식별자와 DNS 연결 대상."
  value       = module.cloudfront.cloudfront
}

output "frontend_url" {
  description = "DNS 연결 후 사용할 프런트엔드 HTTPS 주소."
  value       = "https://${var.frontend_domain_name}"
}

output "s3_buckets" {
  description = "정적 파일·사진·CloudFront 로그 버킷 이름. 기존 지도 버킷은 조회만 합니다."
  value       = { for name, bucket in module.buckets : name => bucket.bucket.id }
}
