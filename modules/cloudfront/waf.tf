resource "aws_wafv2_web_acl" "site" {                                          # CloudFront 요청 검사와 차단 정책 생성
  name   = "CreatedByCloudFront-609132c8"                                      # 웹 ACL 이름 지정
  region = "us-east-1"                                                         # CloudFront WAF 전용 버지니아 북부 리전 사용
  scope  = "CLOUDFRONT"                                                        # 전역 CloudFront 배포 보호 범위
  default_action {                                                             # 어떤 차단 규칙에도 일치하지 않을 때 동작
    allow {}                                                                   # 나머지 요청 허용
  }                                                                            # 설정 묶음 끝
  rule {                                                                       # AWS 관리형 규칙 그룹 추가
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"                     # 웹 ACL 안에서 사용할 규칙 이름
    priority = 1                                                               # 작은 번호부터 검사
    override_action {                                                          # 관리형 규칙 그룹 동작 재정의
      none {}                                                                  # Count로 덮어쓰지 않고 내부 차단 동작 적용
    }                                                                          # 설정 묶음 끝
    statement {                                                                # WAF 요청 검사 조건
      managed_rule_group_statement {                                           # AWS 관리형 규칙 그룹 선택
        name        = "AWSManagedRulesAmazonIpReputationList"                  # Amazon IP 신뢰도 목록 관리형 규칙 그룹
        vendor_name = "AWS"                                                    # 규칙 그룹 제공자 지정
        rule_action_override {                                                 # 개별 관리형 규칙 동작 재정의
          name = "AWSManagedIPDDoSList"                                        # DDoS 활동 IP 규칙 지정
          action_to_use {                                                      # 개별 규칙에 적용할 요청 처리
            block {}                                                           # DDoS 활동 IP 요청 차단
          }                                                                    # 설정 묶음 끝
        }                                                                      # 설정 묶음 끝
      }                                                                        # 설정 묶음 끝
    }                                                                          # 설정 묶음 끝
    visibility_config {                                                        # WAF 지표·요청 샘플 수집 설정
      cloudwatch_metrics_enabled = true                                        # 허용·차단 등 요청 수 지표 수집
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList" # CloudWatch 지표 구분 이름
      sampled_requests_enabled   = false                                       # 요청 샘플 저장 끔
    }                                                                          # 설정 묶음 끝
  }                                                                            # 설정 묶음 끝
  rule {                                                                       # AWS 관리형 규칙 그룹 추가
    name     = "AWS-AWSManagedRulesCommonRuleSet"                              # 웹 ACL 안에서 사용할 규칙 이름
    priority = 2                                                               # 작은 번호부터 검사
    override_action {                                                          # 관리형 규칙 그룹 동작 재정의
      none {}                                                                  # Count로 덮어쓰지 않고 내부 차단 동작 적용
    }                                                                          # 설정 묶음 끝
    statement {                                                                # WAF 요청 검사 조건
      managed_rule_group_statement {                                           # AWS 관리형 규칙 그룹 선택
        name        = "AWSManagedRulesCommonRuleSet"                           # 핵심 규칙 세트(CRS) 관리형 규칙 그룹
        vendor_name = "AWS"                                                    # 규칙 그룹 제공자 지정
      }                                                                        # 설정 묶음 끝
    }                                                                          # 설정 묶음 끝
    visibility_config {                                                        # WAF 지표·요청 샘플 수집 설정
      cloudwatch_metrics_enabled = true                                        # 허용·차단 등 요청 수 지표 수집
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"          # CloudWatch 지표 구분 이름
      sampled_requests_enabled   = false                                       # 요청 샘플 저장 끔
    }                                                                          # 설정 묶음 끝
  }                                                                            # 설정 묶음 끝
  rule {                                                                       # AWS 관리형 규칙 그룹 추가
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"                      # 웹 ACL 안에서 사용할 규칙 이름
    priority = 3                                                               # 작은 번호부터 검사
    override_action {                                                          # 관리형 규칙 그룹 동작 재정의
      none {}                                                                  # Count로 덮어쓰지 않고 내부 차단 동작 적용
    }                                                                          # 설정 묶음 끝
    statement {                                                                # WAF 요청 검사 조건
      managed_rule_group_statement {                                           # AWS 관리형 규칙 그룹 선택
        name        = "AWSManagedRulesKnownBadInputsRuleSet"                   # 알려진 잘못된 입력 관리형 규칙 그룹
        vendor_name = "AWS"                                                    # 규칙 그룹 제공자 지정
      }                                                                        # 설정 묶음 끝
    }                                                                          # 설정 묶음 끝
    visibility_config {                                                        # WAF 지표·요청 샘플 수집 설정
      cloudwatch_metrics_enabled = true                                        # 허용·차단 등 요청 수 지표 수집
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"  # CloudWatch 지표 구분 이름
      sampled_requests_enabled   = false                                       # 요청 샘플 저장 끔
    }                                                                          # 설정 묶음 끝
  }                                                                            # 설정 묶음 끝
  # 속도 기반 규칙은 배포 후 IP별 정상 요청량을 5분 단위로 측정·검증한 뒤 추가

  visibility_config {                                           # WAF 지표·요청 샘플 수집 설정
    cloudwatch_metrics_enabled = true                           # 전체 요청 수 지표 수집
    metric_name                = "CreatedByCloudFront-609132c8" # 웹 ACL 전체 지표 이름
    sampled_requests_enabled   = false                          # 웹 ACL 요청 샘플 저장 끔
  }                                                             # 설정 묶음 끝
}                                                               # 설정 묶음 끝

resource "aws_wafv2_web_acl_logging_configuration" "site" {    # 허용·차단 요청 로그 전달 설정
  region                  = "us-east-1"                        # 웹 ACL과 같은 리전 사용
  resource_arn            = aws_wafv2_web_acl.site.arn         # 기록할 웹 ACL 지정
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn] # 로그 스트림 와일드카드 없이 로그 그룹 ARN 전달
  redacted_fields {                                            # WAF 로그에서 숨길 요청 필드
    single_header {                                            # 기록에서 제외할 HTTP 헤더
      name = "authorization"                                   # authorization 헤더 값 기록 제외
    }                                                          # 설정 묶음 끝
  }                                                            # 설정 묶음 끝
  redacted_fields {                                            # WAF 로그에서 숨길 요청 필드
    single_header {                                            # 기록에서 제외할 HTTP 헤더
      name = "cookie"                                          # cookie 헤더 값 기록 제외
    }                                                          # 설정 묶음 끝
  }                                                            # 설정 묶음 끝
  redacted_fields {                                            # WAF 로그에서 숨길 요청 필드
    single_header {                                            # 기록에서 제외할 HTTP 헤더
      name = "proxy-authorization"                             # proxy-authorization 헤더 값 기록 제외
    }                                                          # 설정 묶음 끝
  }                                                            # 설정 묶음 끝
}                                                              # 설정 묶음 끝
