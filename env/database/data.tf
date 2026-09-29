data "aws_vpc" "main" {           # VPC 조회
  tags = { Name = "arcamap-vpc" } # 리소스 이름·조회용 태그
}                                 # 설정 묶음 끝

data "aws_subnet" "database" {                             # 서브넷 조회
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"]) # 대상 항목별로 블록 반복

  vpc_id            = data.aws_vpc.main.id                      # 리소스를 연결할 VPC ID
  availability_zone = each.key                                  # 서브넷을 배치할 가용 영역
  tags              = { Name = "arcamap-database-${each.key}" } # 리소스 이름·조회용 태그
}                                                               # 설정 묶음 끝

data "aws_security_group" "database" { # 보안 그룹 조회
  name   = "arcamap-database"          # AWS 리소스·규칙·작업 이름
  vpc_id = data.aws_vpc.main.id        # 리소스를 연결할 VPC ID
}                                      # 설정 묶음 끝
