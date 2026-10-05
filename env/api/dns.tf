resource "aws_route53_record" "api" { # DNS 레코드 정의
  provider = aws.dns                  # 리소스에 사용할 공급자 구성

  zone_id         = var.route53_zone_id # DNS 레코드를 만들 호스팅 영역 ID
  name            = var.api_domain_name # 생성할 API·웹 DNS 이름
  type            = "A"                 # DNS 레코드 종류
  allow_overwrite = false               # 같은 이름의 기존 DNS 레코드 덮어쓰기 여부

  alias {                                                           # DNS 별칭 대상 설정
    name                   = "dualstack.${module.alb.alb.dns_name}" # 생성할 API·웹 DNS 이름
    zone_id                = module.alb.alb.zone_id                 # DNS 레코드를 만들 호스팅 영역 ID
    evaluate_target_health = true                                   # DNS 별칭 대상의 상태 평가 여부
  }                                                                 # 설정 묶음 끝
}                                                                   # 설정 묶음 끝
