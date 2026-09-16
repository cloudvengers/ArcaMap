output "cloudfront" {
  description = "CloudFront 배포 식별자와 DNS 연결 대상."
  value = {
    id             = aws_cloudfront_distribution.site.id
    arn            = aws_cloudfront_distribution.site.arn
    domain_name    = aws_cloudfront_distribution.site.domain_name
    hosted_zone_id = aws_cloudfront_distribution.site.hosted_zone_id
  }
}
