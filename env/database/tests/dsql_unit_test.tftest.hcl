mock_provider "aws" {
  override_during = plan

  mock_data "aws_vpc" {
    defaults = {
      id                   = "vpc-00000000"
      enable_dns_support   = true
      enable_dns_hostnames = true
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      id                      = "subnet-00000000"
      map_public_ip_on_launch = false
    }
  }

  mock_data "aws_security_group" {
    defaults = { id = "sg-00000000" }
  }

  mock_data "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:ap-northeast-2:123456789012:arcamap-operations" }
  }

  mock_resource "aws_dsql_cluster" {
    defaults = {
      identifier                = "abcdefghijklmnopqrstuvwx"
      arn                       = "arn:aws:dsql:ap-northeast-2:123456789012:cluster/abcdefghijklmnopqrstuvwx"
      vpc_endpoint_service_name = "com.amazonaws.ap-northeast-2.dsql-test"
    }
  }
}

mock_provider "aws" {
  alias           = "management_service"
  override_during = plan

  mock_resource "aws_dsql_cluster" {
    defaults = {
      identifier                = "abcdefghijklmnopqrstuvwx"
      vpc_endpoint_service_name = "com.amazonaws.ap-northeast-2.dsql"
    }
  }
}

run "dsql_private_connection" {
  command = plan

  module {
    source = "../../modules/database"
  }

  variables {
    vpc_id                          = "vpc-00000000"
    endpoint_subnet_id              = "subnet-00000000"
    dsql_endpoint_security_group_id = "sg-00000000"
  }

  assert {
    condition     = aws_dsql_cluster.main.deletion_protection_enabled && !aws_dsql_cluster.main.force_destroy && length(aws_dsql_cluster.main.multi_region_properties) == 0
    error_message = "단일 리전 DSQL의 삭제 보호를 켜고 강제 삭제를 꺼야 합니다."
  }

  assert {
    condition = (
      aws_vpc_endpoint.database.service_name == "com.amazonaws.ap-northeast-2.dsql-test" &&
      aws_vpc_endpoint.database.vpc_endpoint_type == "Interface" &&
      aws_vpc_endpoint.database.private_dns_enabled &&
      aws_vpc_endpoint.database.vpc_id == "vpc-00000000" &&
      aws_vpc_endpoint.database.subnet_ids == toset(["subnet-00000000"]) &&
      aws_vpc_endpoint.database.security_group_ids == toset(["sg-00000000"])
    )
    error_message = "클러스터별 연결 서비스명·Private DNS·운영 서브넷·Endpoint SG를 사용해야 합니다."
  }

  assert {
    condition = (
      output.database.host == "abcdefghijklmnopqrstuvwx.dsql-test.ap-northeast-2.on.aws" &&
      output.database.auth_host == output.database.host &&
      output.database.dbname == "postgres" && output.database.port == 5432 &&
      output.database.region == "ap-northeast-2" &&
      output.database.cluster_arn == "arn:aws:dsql:ap-northeast-2:123456789012:cluster/abcdefghijklmnopqrstuvwx"
    )
    error_message = "접속과 토큰 생성에 동일한 PrivateLink 호스트를 사용하고 DB·리전·클러스터 계약을 보존해야 합니다."
  }
}

run "reject_management_endpoint_service" {
  command = plan

  providers = { aws = aws.management_service }

  module {
    source = "../../modules/database"
  }

  variables {
    vpc_id                          = "vpc-00000000"
    endpoint_subnet_id              = "subnet-00000000"
    dsql_endpoint_security_group_id = "sg-00000000"
  }

  expect_failures = [aws_dsql_cluster.main]
}

run "network_lookup_and_root_output" {
  command = plan

  assert {
    condition = (
      data.aws_subnet.api.availability_zone == "ap-northeast-2a" &&
      data.aws_subnet.api.tags.Name == "arcamap-api-ap-northeast-2a" &&
      data.aws_security_group.dsql_endpoint.name == "arcamap-dsql-endpoint" &&
      output.database.host == "abcdefghijklmnopqrstuvwx.dsql-test.ap-northeast-2.on.aws"
    )
    error_message = "DB 루트는 확정된 운영 AZ·서브넷·Endpoint SG를 조회하고 PrivateLink 호스트를 전달해야 합니다."
  }
}
