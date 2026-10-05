resource "aws_route53_record" "frontend" { # DNS 레코드 정의
  for_each = toset(["A", "AAAA"])          # 대상 항목별로 블록 반복
  provider = aws.dns                       # 리소스에 사용할 공급자 구성

  zone_id         = data.aws_route53_zone.frontend.zone_id # 확인한 기존 공개 호스팅 영역
  name            = var.frontend_domain_name               # 생성할 API·웹 DNS 이름
  type            = each.key                               # DNS 레코드 종류
  allow_overwrite = false                                  # 같은 이름의 기존 DNS 레코드 덮어쓰기 여부

  alias {                                                                # DNS 별칭 대상 설정
    name                   = module.cloudfront.cloudfront.domain_name    # 생성할 API·웹 DNS 이름
    zone_id                = module.cloudfront.cloudfront.hosted_zone_id # DNS 레코드를 만들 호스팅 영역 ID
    evaluate_target_health = false                                       # DNS 별칭 대상의 상태 평가 여부
  }                                                                      # 설정 묶음 끝
}                                                                        # 설정 묶음 끝
