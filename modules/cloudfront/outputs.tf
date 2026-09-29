output "cloudfront" {                                                # cloudfront 정보를 호출자에게 반환
  description = "CloudFront 배포 식별자와 DNS 연결 대상."                      # 반환하는 값의 의미
  value = {                                                          # 호출자에게 전달할 값
    id             = aws_cloudfront_distribution.site.id             # 호출자에게 전달할 리소스 ID
    arn            = aws_cloudfront_distribution.site.arn            # 리소스 ARN
    domain_name    = aws_cloudfront_distribution.site.domain_name    # 오리진 또는 인증서 도메인
    hosted_zone_id = aws_cloudfront_distribution.site.hosted_zone_id # DNS 별칭 대상의 호스팅 영역 ID
  }                                                                  # 설정 묶음 끝
}                                                                    # 설정 묶음 끝
