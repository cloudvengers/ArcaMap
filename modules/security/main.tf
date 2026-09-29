resource "aws_security_group" "alb" { # 보안 그룹 정의
  name   = "arcamap-alb"              # AWS 리소스·규칙·작업 이름
  vpc_id = var.vpc_id                 # 리소스를 연결할 VPC ID
}                                     # 설정 묶음 끝

resource "aws_security_group" "api" { # 보안 그룹 정의
  name   = "arcamap-api"              # AWS 리소스·규칙·작업 이름
  vpc_id = var.vpc_id                 # 리소스를 연결할 VPC ID
}                                     # 설정 묶음 끝

resource "aws_security_group" "database" { # 보안 그룹 정의
  name   = "arcamap-database"              # AWS 리소스·규칙·작업 이름
  vpc_id = var.vpc_id                      # 리소스를 연결할 VPC ID
}                                          # 설정 묶음 끝

resource "aws_vpc_security_group_ingress_rule" "alb_http" { # 보안 그룹 인바운드 규칙 정의
  security_group_id = aws_security_group.alb.id             # 통신 규칙을 적용할 보안 그룹 ID
  cidr_ipv4         = "0.0.0.0/0"                           # 통신을 허용할 IPv4 CIDR
  ip_protocol       = "tcp"                                 # 허용할 전송 프로토콜
  from_port         = 80                                    # 허용 포트 범위의 시작
  to_port           = 80                                    # 허용 포트 범위의 끝
}                                                           # 설정 묶음 끝

resource "aws_vpc_security_group_ingress_rule" "alb_https" { # 보안 그룹 인바운드 규칙 정의
  security_group_id = aws_security_group.alb.id              # 통신 규칙을 적용할 보안 그룹 ID
  cidr_ipv4         = "0.0.0.0/0"                            # 통신을 허용할 IPv4 CIDR
  ip_protocol       = "tcp"                                  # 허용할 전송 프로토콜
  from_port         = 443                                    # 허용 포트 범위의 시작
  to_port           = 443                                    # 허용 포트 범위의 끝
}                                                            # 설정 묶음 끝

resource "aws_vpc_security_group_egress_rule" "alb_api" {  # 보안 그룹 아웃바운드 규칙 정의
  security_group_id            = aws_security_group.alb.id # 통신 규칙을 적용할 보안 그룹 ID
  referenced_security_group_id = aws_security_group.api.id # 통신 상대의 보안 그룹 ID
  ip_protocol                  = "tcp"                     # 허용할 전송 프로토콜
  from_port                    = 8080                      # 허용 포트 범위의 시작
  to_port                      = 8080                      # 허용 포트 범위의 끝
}                                                          # 설정 묶음 끝

resource "aws_vpc_security_group_ingress_rule" "api_alb" { # 보안 그룹 인바운드 규칙 정의
  security_group_id            = aws_security_group.api.id # 통신 규칙을 적용할 보안 그룹 ID
  referenced_security_group_id = aws_security_group.alb.id # 통신 상대의 보안 그룹 ID
  ip_protocol                  = "tcp"                     # 허용할 전송 프로토콜
  from_port                    = 8080                      # 허용 포트 범위의 시작
  to_port                      = 8080                      # 허용 포트 범위의 끝
}                                                          # 설정 묶음 끝

resource "aws_vpc_security_group_egress_rule" "api_database" {  # 보안 그룹 아웃바운드 규칙 정의
  security_group_id            = aws_security_group.api.id      # 통신 규칙을 적용할 보안 그룹 ID
  referenced_security_group_id = aws_security_group.database.id # 통신 상대의 보안 그룹 ID
  ip_protocol                  = "tcp"                          # 허용할 전송 프로토콜
  from_port                    = 5432                           # 허용 포트 범위의 시작
  to_port                      = 5432                           # 허용 포트 범위의 끝
}                                                               # 설정 묶음 끝

resource "aws_vpc_security_group_egress_rule" "api_https" { # 보안 그룹 아웃바운드 규칙 정의
  security_group_id = aws_security_group.api.id             # 통신 규칙을 적용할 보안 그룹 ID
  cidr_ipv4         = "0.0.0.0/0"                           # 통신을 허용할 IPv4 CIDR
  ip_protocol       = "tcp"                                 # 허용할 전송 프로토콜
  from_port         = 443                                   # 허용 포트 범위의 시작
  to_port           = 443                                   # 허용 포트 범위의 끝
}                                                           # 설정 묶음 끝

resource "aws_vpc_security_group_ingress_rule" "database_api" { # 보안 그룹 인바운드 규칙 정의
  security_group_id            = aws_security_group.database.id # 통신 규칙을 적용할 보안 그룹 ID
  referenced_security_group_id = aws_security_group.api.id      # 통신 상대의 보안 그룹 ID
  ip_protocol                  = "tcp"                          # 허용할 전송 프로토콜
  from_port                    = 5432                           # 허용 포트 범위의 시작
  to_port                      = 5432                           # 허용 포트 범위의 끝
}                                                               # 설정 묶음 끝
