data "aws_vpc" "main" {
  tags = { Name = "arcamap-vpc" }

  lifecycle {
    postcondition {
      condition     = self.enable_dns_support && self.enable_dns_hostnames
      error_message = "DSQL Private DNS를 사용하려면 VPC의 DNS 지원과 DNS 호스트 이름을 활성화해야 합니다."
    }
  }
}

data "aws_subnet" "api" {
  vpc_id            = data.aws_vpc.main.id
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "arcamap-api-ap-northeast-2a" }

  lifecycle {
    postcondition {
      condition     = !self.map_public_ip_on_launch
      error_message = "DSQL Endpoint는 공인 IP 자동 할당이 꺼진 운영 API 프라이빗 서브넷을 사용해야 합니다."
    }
  }
}

data "aws_security_group" "dsql_endpoint" {
  name   = "arcamap-dsql-endpoint"
  vpc_id = data.aws_vpc.main.id
}
