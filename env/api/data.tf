data "aws_vpc" "main" {           # VPC 조회
  tags = { Name = "arcamap-vpc" } # 리소스 이름·조회용 태그
}                                 # 설정 묶음 끝

data "aws_subnet" "public" {                               # 서브넷 조회
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"]) # 대상 항목별로 블록 반복

  vpc_id            = data.aws_vpc.main.id                    # 리소스를 연결할 VPC ID
  availability_zone = each.key                                # 서브넷을 배치할 가용 영역
  tags              = { Name = "arcamap-public-${each.key}" } # 리소스 이름·조회용 태그
}                                                             # 설정 묶음 끝

data "aws_subnet" "api" {                                  # 서브넷 조회
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"]) # 대상 항목별로 블록 반복

  vpc_id            = data.aws_vpc.main.id                 # 리소스를 연결할 VPC ID
  availability_zone = each.key                             # 서브넷을 배치할 가용 영역
  tags              = { Name = "arcamap-api-${each.key}" } # 리소스 이름·조회용 태그
}                                                          # 설정 묶음 끝

data "aws_security_group" "alb" { # 보안 그룹 조회
  name   = "arcamap-alb"          # AWS 리소스·규칙·작업 이름
  vpc_id = data.aws_vpc.main.id   # 리소스를 연결할 VPC ID
}                                 # 설정 묶음 끝

data "aws_security_group" "api" { # 보안 그룹 조회
  name   = "arcamap-api"          # AWS 리소스·규칙·작업 이름
  vpc_id = data.aws_vpc.main.id   # 리소스를 연결할 VPC ID
}                                 # 설정 묶음 끝

data "aws_acm_certificate" "api" {  # ACM 인증서 조회
  domain      = var.api_domain_name # EIP 또는 조회 대상의 도메인 지정
  statuses    = ["ISSUED"]          # 조회할 ACM 인증서 상태
  most_recent = false               # 조회 결과 중 최신 항목 선택 여부
}                                   # 설정 묶음 끝

data "aws_db_instance" "postgres" {           # RDS PostgreSQL 인스턴스 조회
  db_instance_identifier = "arcamap-postgres" # 조회할 기존 RDS 식별자
}                                             # 설정 묶음 끝
