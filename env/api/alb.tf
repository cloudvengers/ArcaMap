module "alb" {                 # API ALB·WAF 모듈 연결
  source = "../../modules/alb" # 로컬 하위 모듈 경로

  vpc_id                = data.aws_vpc.main.id                               # 리소스를 연결할 VPC ID
  public_subnet_ids     = [for subnet in data.aws_subnet.public : subnet.id] # ALB를 배치할 퍼블릭 서브넷 ID 목록
  alb_security_group_id = data.aws_security_group.alb.id                     # ALB에 연결할 보안 그룹 ID
  certificate_arn       = var.certificate_arn                                # TLS 인증서 ARN
  log_group_arn         = module.log_groups["alb"].log_group.arn             # ALB 로그 전달 대상 로그 그룹 ARN
}                                                                            # 설정 묶음 끝
