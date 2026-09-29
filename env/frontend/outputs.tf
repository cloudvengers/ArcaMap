output "cloudfront" {                           # cloudfront 정보를 호출자에게 반환
  description = "CloudFront 배포 식별자와 DNS 연결 대상." # 반환하는 값의 의미
  value       = module.cloudfront.cloudfront    # 호출자에게 전달할 값
}                                               # 설정 묶음 끝

output "frontend_url" {                               # frontend_url 정보를 호출자에게 반환
  description = "DNS 연결 후 사용할 프런트엔드 HTTPS 주소."        # 반환하는 값의 의미
  value       = "https://${var.frontend_domain_name}" # 호출자에게 전달할 값
}                                                     # 설정 묶음 끝

output "s3_buckets" {                                                             # s3_buckets 정보를 호출자에게 반환
  description = "정적 파일·사진·CloudFront 로그 버킷 이름. 기존 지도 버킷은 조회만 합니다."                # 반환하는 값의 의미
  value       = { for name, bucket in module.buckets : name => bucket.bucket.id } # 호출자에게 전달할 값
}                                                                                 # 설정 묶음 끝
