resource "aws_vpc" "main" {            # VPC 정의
  cidr_block           = "10.0.0.0/16" # IP 주소 범위(CIDR)
  enable_dns_support   = true          # VPC DNS 해석 지원 여부
  enable_dns_hostnames = true          # VPC DNS 호스트 이름 지원 여부
  instance_tenancy     = "default"     # VPC 인스턴스 하드웨어 공유 방식

  tags = { Name = "arcamap-vpc" } # 리소스 이름·조회용 태그
}                                 # 설정 묶음 끝

resource "aws_internet_gateway" "main" { # 인터넷 게이트웨이 정의
  vpc_id = aws_vpc.main.id               # 리소스를 연결할 VPC ID
}                                        # 설정 묶음 끝

resource "aws_subnet" "public" {      # 서브넷 정의
  for_each = {                        # 대상 항목별로 블록 반복
    "ap-northeast-2a" = "10.0.1.0/24" # 서울 2a 가용 영역의 서브넷 CIDR
    "ap-northeast-2c" = "10.0.2.0/24" # 서울 2c 가용 영역의 서브넷 CIDR
  }                                   # 설정 묶음 끝

  vpc_id                  = aws_vpc.main.id # 리소스를 연결할 VPC ID
  availability_zone       = each.key        # 서브넷을 배치할 가용 영역
  cidr_block              = each.value      # IP 주소 범위(CIDR)
  map_public_ip_on_launch = false           # 서브넷 EC2의 공인 IP 자동 할당 여부

  tags = { Name = "arcamap-public-${each.key}" } # 리소스 이름·조회용 태그
}                                                # 설정 묶음 끝

resource "aws_subnet" "api" {          # 서브넷 정의
  for_each = {                         # 대상 항목별로 블록 반복
    "ap-northeast-2a" = "10.0.11.0/24" # 서울 2a 가용 영역의 서브넷 CIDR
    "ap-northeast-2c" = "10.0.12.0/24" # 서울 2c 가용 영역의 서브넷 CIDR
  }                                    # 설정 묶음 끝

  vpc_id                  = aws_vpc.main.id # 리소스를 연결할 VPC ID
  availability_zone       = each.key        # 서브넷을 배치할 가용 영역
  cidr_block              = each.value      # IP 주소 범위(CIDR)
  map_public_ip_on_launch = false           # 서브넷 EC2의 공인 IP 자동 할당 여부

  tags = { Name = "arcamap-api-${each.key}" } # 리소스 이름·조회용 태그
}                                             # 설정 묶음 끝

resource "aws_subnet" "database" {     # 서브넷 정의
  for_each = {                         # 대상 항목별로 블록 반복
    "ap-northeast-2a" = "10.0.21.0/24" # 서울 2a 가용 영역의 서브넷 CIDR
    "ap-northeast-2c" = "10.0.22.0/24" # 서울 2c 가용 영역의 서브넷 CIDR
  }                                    # 설정 묶음 끝

  vpc_id                  = aws_vpc.main.id # 리소스를 연결할 VPC ID
  availability_zone       = each.key        # 서브넷을 배치할 가용 영역
  cidr_block              = each.value      # IP 주소 범위(CIDR)
  map_public_ip_on_launch = false           # 서브넷 EC2의 공인 IP 자동 할당 여부

  tags = { Name = "arcamap-database-${each.key}" } # 리소스 이름·조회용 태그
}                                                  # 설정 묶음 끝

resource "aws_eip" "nat" {     # NAT용 고정 공인 IP 정의
  for_each = aws_subnet.public # 대상 항목별로 블록 반복

  domain = "vpc" # EIP 또는 조회 대상의 도메인 지정
}                # 설정 묶음 끝

resource "aws_nat_gateway" "public" { # NAT 게이트웨이 정의
  for_each = aws_subnet.public        # 대상 항목별로 블록 반복

  availability_mode = "zonal"                        # NAT 게이트웨이의 가용 영역 배치 방식
  connectivity_type = "public"                       # NAT 게이트웨이의 외부 연결 방식
  subnet_id         = aws_subnet.public[each.key].id # 리소스를 배치할 서브넷 ID
  allocation_id     = aws_eip.nat[each.key].id       # NAT 게이트웨이에 연결할 EIP 할당 ID

  depends_on = [aws_internet_gateway.main] # 참조만으로 표현되지 않는 선행 작업 지정
}                                          # 설정 묶음 끝

resource "aws_route_table" "public" { # 라우팅 테이블 정의
  vpc_id = aws_vpc.main.id            # 리소스를 연결할 VPC ID

  route {                                     # 목적지별 라우팅 경로
    cidr_block = "0.0.0.0/0"                  # IP 주소 범위(CIDR)
    gateway_id = aws_internet_gateway.main.id # 외부 통신에 사용할 인터넷 게이트웨이 ID
  }                                           # 설정 묶음 끝
}                                             # 설정 묶음 끝

resource "aws_route_table" "api" { # 라우팅 테이블 정의
  for_each = aws_subnet.api        # 대상 항목별로 블록 반복

  vpc_id = aws_vpc.main.id # 리소스를 연결할 VPC ID

  route {                                                # 목적지별 라우팅 경로
    cidr_block     = "0.0.0.0/0"                         # IP 주소 범위(CIDR)
    nat_gateway_id = aws_nat_gateway.public[each.key].id # API 외부 통신에 사용할 NAT 게이트웨이 ID
  }                                                      # 설정 묶음 끝
}                                                        # 설정 묶음 끝

resource "aws_route_table" "database" { # 라우팅 테이블 정의
  vpc_id = aws_vpc.main.id              # 리소스를 연결할 VPC ID
  route  = []                           # 명시적인 외부 라우팅 규칙 목록
}                                       # 설정 묶음 끝

resource "aws_route_table_association" "public" { # 서브넷과 라우팅 테이블 연결 정의
  for_each = aws_subnet.public                    # 대상 항목별로 블록 반복

  subnet_id      = each.value.id             # 리소스를 배치할 서브넷 ID
  route_table_id = aws_route_table.public.id # 서브넷에 연결할 라우팅 테이블 ID
}                                            # 설정 묶음 끝

resource "aws_route_table_association" "api" { # 서브넷과 라우팅 테이블 연결 정의
  for_each = aws_subnet.api                    # 대상 항목별로 블록 반복

  subnet_id      = each.value.id                    # 리소스를 배치할 서브넷 ID
  route_table_id = aws_route_table.api[each.key].id # 서브넷에 연결할 라우팅 테이블 ID
}                                                   # 설정 묶음 끝

resource "aws_route_table_association" "database" { # 서브넷과 라우팅 테이블 연결 정의
  for_each = aws_subnet.database                    # 대상 항목별로 블록 반복

  subnet_id      = each.value.id               # 리소스를 배치할 서브넷 ID
  route_table_id = aws_route_table.database.id # 서브넷에 연결할 라우팅 테이블 ID
}                                              # 설정 묶음 끝
