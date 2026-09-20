mock_provider "aws" {
  override_during = plan

  mock_resource "aws_subnet" {}
  mock_resource "aws_nat_gateway" {}
  mock_resource "aws_route_table" {}

  mock_resource "aws_vpc" {
    defaults = { id = "vpc-00000000000000001" }
  }

  mock_resource "aws_security_group" {
    defaults = { id = "sg-00000000000000001" }
  }
}

run "app_outputs" {
  command = plan

  assert {
    condition = (
      output.vpc_id == "vpc-00000000000000001" &&
      toset(keys(output.public_subnet_ids)) == toset(["ap-northeast-2a", "ap-northeast-2c"]) &&
      toset(keys(output.api_subnet_ids)) == toset(["ap-northeast-2a", "ap-northeast-2c"]) &&
      toset(keys(output.database_subnet_ids)) == toset(["ap-northeast-2a", "ap-northeast-2c"]) &&
      output.alb_security_group_id != null &&
      output.api_security_group_id != null &&
      output.database_security_group_id != null
    )
    error_message = "app은 VPC·AZ별 세 종류 서브넷·세 역할의 보안 그룹 ID를 제공해야 합니다."
  }
}

run "network_isolation_and_routes" {
  command = plan

  module {
    source = "../../modules/network"
  }

  assert {
    condition = (
      aws_vpc.main.cidr_block == "10.0.0.0/16" &&
      aws_vpc.main.tags["Name"] == "arcamap-vpc" &&
      length(aws_subnet.public) == 2 &&
      length(aws_subnet.api) == 2 &&
      length(aws_subnet.database) == 2 &&
      length(aws_nat_gateway.public) == 2 &&
      length(aws_route_table.database.route) == 0 &&
      alltrue([for subnet in aws_subnet.public : !subnet.map_public_ip_on_launch])
    )
    error_message = "2개 AZ의 공개·API·DB 서브넷, AZ별 NAT, DB 기본 경로 차단을 유지해야 합니다."
  }

  assert {
    condition = alltrue([
      for az in ["ap-northeast-2a", "ap-northeast-2c"] :
      aws_subnet.public[az].tags["Name"] == "arcamap-public-${az}" &&
      aws_subnet.api[az].tags["Name"] == "arcamap-api-${az}" &&
      aws_subnet.database[az].tags["Name"] == "arcamap-database-${az}" &&
      aws_route_table_association.api[az].subnet_id == aws_subnet.api[az].id &&
      aws_route_table_association.api[az].route_table_id == aws_route_table.api[az].id &&
      one(aws_route_table.api[az].route).nat_gateway_id == aws_nat_gateway.public[az].id &&
      !aws_subnet.api[az].map_public_ip_on_launch &&
      !aws_subnet.database[az].map_public_ip_on_launch
    ])
    error_message = "역할·AZ별 조회 태그와 같은 AZ NAT 연결을 유지하고 API·DB의 공개 IP 자동 부여를 차단해야 합니다."
  }
}

run "security_boundaries" {
  command = plan

  module {
    source = "../../modules/security"
  }

  variables {
    vpc_id = "vpc-00000000000000001"
  }

  assert {
    condition = (
      aws_security_group.alb.name == "arcamap-alb" &&
      aws_security_group.api.name == "arcamap-api" &&
      aws_security_group.database.name == "arcamap-database" &&
      aws_vpc_security_group_ingress_rule.api_alb.from_port == 8080 &&
      aws_vpc_security_group_ingress_rule.api_alb.to_port == 8080 &&
      aws_vpc_security_group_ingress_rule.api_alb.referenced_security_group_id == aws_security_group.alb.id &&
      aws_vpc_security_group_ingress_rule.database_api.from_port == 5432 &&
      aws_vpc_security_group_ingress_rule.database_api.to_port == 5432 &&
      aws_vpc_security_group_ingress_rule.database_api.referenced_security_group_id == aws_security_group.api.id &&
      aws_vpc_security_group_egress_rule.api_database.referenced_security_group_id == aws_security_group.database.id &&
      aws_vpc_security_group_egress_rule.api_https.from_port == 443
    )
    error_message = "ALB→API 8080, API→DB 5432 및 API 외부 HTTPS 경계를 유지해야 합니다."
  }
}
