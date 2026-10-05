module "dashboard" {                            # 통합 대시보드 모듈 연결
  source = "../../modules/cloudwatch-dashboard" # 로컬 하위 모듈 경로

  asg_name                = data.aws_autoscaling_group.api.name                                                              # API Auto Scaling 그룹 이름
  alb_arn_suffix          = data.aws_lb.api.arn_suffix                                                                       # ALB 지표 차원의 ARN 접미사
  target_group_arn_suffix = data.aws_lb_target_group.api.arn_suffix                                                          # 대상 그룹 지표 차원의 ARN 접미사
  log_groups              = { for key, group in data.aws_cloudwatch_log_groups.service : key => one(group.log_group_names) } # 대시보드에서 조회할 로그 그룹 이름
  dsql_cluster_identifier = var.dsql_cluster_identifier
  # 현재 두 Web ACL은 이름과 visibility_config.metric_name이 같습니다.
  waf_metric_names = {                                  # API·CloudFront 웹 ACL의 지표 이름
    api        = data.aws_wafv2_web_acl.api.name        # API 항목 설정
    cloudfront = data.aws_wafv2_web_acl.cloudfront.name # CloudFront WAF 조회·연결 정보
  }                                                     # 설정 묶음 끝
  alarm_arns = [for name in [                           # 대시보드에 표시할 경보 ARN 목록
    "arcamap-asg-inservice",                            # 대시보드에 표시할 서비스 경보 이름
    "arcamap-ec2-status-check",                         # 대시보드에 표시할 서비스 경보 이름
    "arcamap-ec2-cpu",                                  # 대시보드에 표시할 서비스 경보 이름
    "arcamap-ec2-memory",                               # 대시보드에 표시할 서비스 경보 이름
    "arcamap-alb-healthy-hosts",                        # 대시보드에 표시할 서비스 경보 이름
    "arcamap-alb-5xx",                                  # 대시보드에 표시할 서비스 경보 이름
    "arcamap-api-5xx",                                  # 대시보드에 표시할 서비스 경보 이름
    "arcamap-dsql-cluster-connections",
  ] : "arn:aws:cloudwatch:ap-northeast-2:${data.aws_caller_identity.current.account_id}:alarm:${name}"] # 현재 계정의 서비스 경보 ARN 생성
}                                                                                                       # 설정 묶음 끝
