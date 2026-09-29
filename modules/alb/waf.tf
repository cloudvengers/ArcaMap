resource "aws_wafv2_web_acl" "api" {                                           # API 요청 검사와 차단 정책 생성
  name   = "arcamap-api"                                                       # 웹 ACL 이름 지정
  region = "ap-northeast-2"                                                    # ALB가 위치한 서울 리전 사용
  scope  = "REGIONAL"                                                          # 리전 안의 ALB 보호 범위
  default_action {                                                             # 어떤 차단 규칙에도 일치하지 않을 때 동작
    allow {}                                                                   # 나머지 요청 허용
  }                                                                            # 설정 묶음 끝
  rule {                                                                       # DB 점검 주소 외부 접근 차단 규칙
    name     = "block-db-health"                                               # 경로 차단 규칙 이름
    priority = 0                                                               # 관리형 그룹보다 먼저 검사
    action {                                                                   # 일치 요청 처리 동작
      block {}                                                                 # ALB를 통해 들어오는 DB 점검 요청 차단
    }                                                                          # 설정 묶음 끝
    statement {                                                                # WAF 요청 검사 조건
      regex_match_statement {                                                  # 끝 슬래시를 포함한 경로 검사
        regex_string = "^/health/db/?$"                                        # DB 점검 주소와 끝 슬래시 변형 일치
        field_to_match {                                                       # 검사할 요청 필드
          uri_path {}                                                          # 쿼리 문자열을 제외한 URI 경로 검사
        }                                                                      # 설정 묶음 끝
        text_transformation {                                                  # 검사 전 요청 내용 정규화
          priority = 0                                                         # 경로 정규화보다 먼저 실행
          type     = "URL_DECODE"                                              # 퍼센트 인코딩 문자 해석
        }                                                                      # 설정 묶음 끝
        text_transformation {                                                  # 검사 전 요청 내용 정규화
          priority = 1                                                         # URL 디코딩 다음 실행
          type     = "NORMALIZE_PATH"                                          # 중복 슬래시와 상대 경로 요소 정리
        }                                                                      # 설정 묶음 끝
      }                                                                        # 설정 묶음 끝
    }                                                                          # 설정 묶음 끝
    visibility_config {                                                        # WAF 지표·요청 샘플 수집 설정
      cloudwatch_metrics_enabled = true                                        # 차단 건수 지표 수집
      metric_name                = "block-db-health"                           # 경로 차단 지표 이름
      sampled_requests_enabled   = false                                       # 요청 샘플 저장 끔
    }                                                                          # 설정 묶음 끝
  }                                                                            # 설정 묶음 끝
  rule {                                                                       # AWS 관리형 규칙 그룹 추가
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"                     # 웹 ACL 안에서 사용할 규칙 이름
    priority = 1                                                               # 작은 번호부터 검사
    override_action {                                                          # 관리형 규칙 그룹 동작 재정의
      none {}                                                                  # Count로 덮어쓰지 않고 내부 차단 동작 적용
    }                                                                          # 설정 묶음 끝
    statement {                                                                # WAF 요청 검사 조건
      managed_rule_group_statement {                                           # AWS 관리형 규칙 그룹 선택
        name        = "AWSManagedRulesAmazonIpReputationList"                  # AWS가 제공하는 관리형 규칙 그룹 이름
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
        name        = "AWSManagedRulesCommonRuleSet"                           # AWS가 제공하는 관리형 규칙 그룹 이름
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
        name        = "AWSManagedRulesKnownBadInputsRuleSet"                   # AWS가 제공하는 관리형 규칙 그룹 이름
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

  visibility_config {                          # WAF 지표·요청 샘플 수집 설정
    cloudwatch_metrics_enabled = true          # 전체 요청 수 지표 수집
    metric_name                = "arcamap-api" # 웹 ACL 전체 지표 이름
    sampled_requests_enabled   = false         # 웹 ACL 요청 샘플 저장 끔
  }                                            # 설정 묶음 끝
}                                              # 설정 묶음 끝

resource "aws_wafv2_web_acl_logging_configuration" "api" {     # 허용·차단 요청 로그 전달 설정
  region                  = "ap-northeast-2"                   # 웹 ACL과 같은 리전 사용
  resource_arn            = aws_wafv2_web_acl.api.arn          # 기록할 웹 ACL 지정
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn] # CloudWatch 로그 그룹으로 전달
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

resource "aws_wafv2_web_acl_association" "api" { # API ALB에 웹 ACL 연결
  region       = "ap-northeast-2"                # ALB와 웹 ACL이 있는 서울 리전
  resource_arn = aws_lb.api.arn                  # 보호할 API ALB 지정
  web_acl_arn  = aws_wafv2_web_acl.api.arn       # API 웹 ACL 지정
}                                                # 설정 묶음 끝
