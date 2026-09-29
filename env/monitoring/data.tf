data "aws_caller_identity" "current" {} # 현재 AWS 계정 조회

data "aws_autoscaling_group" "api" { # Auto Scaling 그룹 조회
  name = "arcamap-api"               # AWS 리소스·규칙·작업 이름

  lifecycle {                                             # 리소스 생성·교체와 검증 규칙
    postcondition {                                       # 조회 결과 검증 조건
      condition     = length(self.target_group_arns) == 1 # 조회 결과가 만족해야 할 조건
      error_message = "API ASG에 연결된 대상 그룹이 정확히 하나여야 합니다." # 검증 조건을 만족하지 않을 때 표시할 오류
    }                                                     # 설정 묶음 끝
  }                                                       # 설정 묶음 끝
}                                                         # 설정 묶음 끝

data "aws_lb" "api" {  # API 로드 밸런서 조회
  name = "arcamap-api" # AWS 리소스·규칙·작업 이름
}                      # 설정 묶음 끝

data "aws_lb_target_group" "api" {                            # API 대상 그룹 조회
  arn = one(data.aws_autoscaling_group.api.target_group_arns) # 리소스 ARN
}                                                             # 설정 묶음 끝

data "aws_wafv2_web_acl" "api" { # WAF 웹 ACL 조회
  name  = "arcamap-api"          # AWS 리소스·규칙·작업 이름
  scope = "REGIONAL"             # WAF 보호 범위
}                                # 설정 묶음 끝

data "aws_wafv2_web_acl" "cloudfront" {   # WAF 웹 ACL 조회
  name   = "CreatedByCloudFront-609132c8" # AWS 리소스·규칙·작업 이름
  scope  = "CLOUDFRONT"                   # WAF 보호 범위
  region = "us-east-1"                    # 리소스 생성·조회 또는 지표 표시 리전
}                                         # 설정 묶음 끝

data "aws_cloudwatch_log_groups" "service" {                                                   # CloudWatch 로그 그룹 목록 조회
  for_each = {                                                                                 # 대상 항목별로 블록 반복
    alb            = { prefix = "/aws/vendedlogs/elb/arcamap-api", region = "ap-northeast-2" } # ALB 로그 그룹 조회·연결 정보
    system         = { prefix = "/arcamap/ec2/system", region = "ap-northeast-2" }             # 시스템 로그 조회 정보
    waf_api        = { prefix = "aws-waf-logs-arcamap-api", region = "ap-northeast-2" }        # API WAF 로그 그룹 조회 정보
    waf_cloudfront = { prefix = "aws-waf-logs-CloudFrontDistribution-", region = "us-east-1" } # CloudFront WAF 로그 그룹 조회 정보
  }                                                                                            # 설정 묶음 끝

  region                = each.value.region # 리소스 생성·조회 또는 지표 표시 리전
  log_group_name_prefix = each.value.prefix # 조회할 로그 그룹 이름 접두사

  lifecycle {                                                                               # 리소스 생성·교체와 검증 규칙
    postcondition {                                                                         # 조회 결과 검증 조건
      condition     = length(self.log_group_names) == 1                                     # 조회 결과가 만족해야 할 조건
      error_message = "${each.key} 로그 그룹이 정확히 하나여야 합니다. API·프런트엔드 배포 여부와 로그 그룹 접두사를 확인하세요." # 검증 조건을 만족하지 않을 때 표시할 오류
    }                                                                                       # 설정 묶음 끝
  }                                                                                         # 설정 묶음 끝
}                                                                                           # 설정 묶음 끝
