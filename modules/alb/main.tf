resource "aws_lb" "api" {                          # API 로드 밸런서 정의
  name               = "arcamap-api"               # AWS 리소스·규칙·작업 이름
  load_balancer_type = "application"               # 로드 밸런서 종류
  internal           = false                       # 내부 전용 로드 밸런서 여부
  ip_address_type    = "ipv4"                      # 로드 밸런서 IP 주소 유형
  security_groups    = [var.alb_security_group_id] # ALB에 연결할 보안 그룹 ID 목록
  subnets            = var.public_subnet_ids       # ALB를 배치할 서브넷 ID 목록

  idle_timeout      = 60   # ALB 유휴 연결 제한 시간(초)
  client_keep_alive = 3600 # ALB 클라이언트 연결 유지 시간(초)
  enable_http2      = true # ALB HTTP/2 지원 여부
}                          # 설정 묶음 끝

resource "aws_lb_target_group" "api" { # API 대상 그룹 정의
  vpc_id           = var.vpc_id        # 리소스를 연결할 VPC ID
  target_type      = "instance"        # ALB 대상 등록 방식
  protocol         = "HTTP"            # 통신 또는 상태 검사 프로토콜
  port             = 8080              # 연결을 받을 포트
  protocol_version = "HTTP1"           # 대상 그룹 HTTP 프로토콜 버전

  load_balancing_algorithm_type     = "round_robin"                     # API 대상 간 요청 분산 방식
  load_balancing_cross_zone_enabled = "use_load_balancer_configuration" # 가용 영역 간 요청 분산 방식
  slow_start                        = 0                                 # 새 대상의 요청 비중 증가 시간(초)
  deregistration_delay              = 300                               # 대상 해제 시 진행 중 요청 대기 시간(초)

  health_check {                         # API 대상 상태 검사 설정
    protocol            = "HTTP"         # 통신 또는 상태 검사 프로토콜
    port                = "traffic-port" # 연결을 받을 포트
    path                = "/health"      # ALB 상태 검사 URL 경로
    matcher             = "200"          # 정상 응답으로 인정할 HTTP 상태 코드
    interval            = 30             # ALB 상태 검사 주기(초)
    timeout             = 5              # ALB 상태 검사 응답 제한 시간(초)
    healthy_threshold   = 5              # 정상 판정에 필요한 연속 성공 횟수
    unhealthy_threshold = 2              # 비정상 판정에 필요한 연속 실패 횟수
  }                                      # 설정 묶음 끝
}                                        # 설정 묶음 끝

resource "aws_lb_listener" "api_http" { # ALB 리스너 정의
  load_balancer_arn = aws_lb.api.arn    # 리스너를 연결할 ALB ARN
  port              = 80                # 연결을 받을 포트
  protocol          = "HTTP"            # 통신 또는 상태 검사 프로토콜

  default_action {    # 조건에 일치하지 않을 때의 기본 처리
    type = "redirect" # 리스너 요청 처리 방식

    redirect {                 # HTTP 요청 리다이렉트 설정
      port        = "443"      # 연결을 받을 포트
      protocol    = "HTTPS"    # 통신 또는 상태 검사 프로토콜
      status_code = "HTTP_301" # HTTP 리다이렉트 응답 코드
    }                          # 설정 묶음 끝
  }                            # 설정 묶음 끝
}                              # 설정 묶음 끝

resource "aws_lb_listener" "api_https" {                           # ALB 리스너 정의
  load_balancer_arn = aws_lb.api.arn                               # 리스너를 연결할 ALB ARN
  port              = 443                                          # 연결을 받을 포트
  protocol          = "HTTPS"                                      # 통신 또는 상태 검사 프로토콜
  certificate_arn   = var.certificate_arn                          # TLS 인증서 ARN
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09" # ALB HTTPS 리스너의 TLS 보안 정책

  default_action {                                 # 조건에 일치하지 않을 때의 기본 처리
    type             = "forward"                   # 리스너 요청 처리 방식
    target_group_arn = aws_lb_target_group.api.arn # API 요청을 전달할 대상 그룹 ARN
  }                                                # 설정 묶음 끝
}                                                  # 설정 묶음 끝
