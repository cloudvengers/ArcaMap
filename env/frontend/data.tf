data "aws_caller_identity" "current" {} # 현재 AWS 계정 조회

data "aws_route53_zone" "frontend" {
  provider = aws.dns
  zone_id  = var.route53_zone_id

  lifecycle {
    postcondition {
      condition     = length(self.name_servers) > 0 && trimsuffix(self.name, ".") == var.frontend_domain_name
      error_message = "프런트엔드 DNS는 지정 도메인의 기존 공개 호스팅 영역이어야 합니다."
    }
  }
}
