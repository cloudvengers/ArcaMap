# terraform -chdir=env/network test: AWS 요청 없이 배치·통신 경계를 검사합니다.
mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = { id = "vpc-00000001" }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-00000003" }
  }

  mock_resource "aws_eip" {
    defaults = { id = "eipalloc-00000001" }
  }

  mock_resource "aws_nat_gateway" {
    defaults = { id = "nat-00000001" }
  }

  mock_resource "aws_internet_gateway" {
    defaults = { id = "igw-00000001" }
  }

  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:ap-northeast-2:123456789012:arcamap-operations" }
  }
}

run "network_placement" {
  command = plan

  module {
    source = "../../modules/network"
  }

  override_resource {
    target          = aws_subnet.public["ap-northeast-2a"]
    override_during = plan
    values          = { id = "subnet-00000001" }
  }

  override_resource {
    target          = aws_subnet.public["ap-northeast-2c"]
    override_during = plan
    values          = { id = "subnet-00000002" }
  }

  assert {
    condition = (
      keys(aws_subnet.public) == ["ap-northeast-2a", "ap-northeast-2c"] &&
      keys(aws_subnet.api) == ["ap-northeast-2a"] &&
      keys(aws_eip.nat) == ["ap-northeast-2a"] &&
      keys(aws_nat_gateway.public) == ["ap-northeast-2a"] &&
      keys(aws_route_table.api) == ["ap-northeast-2a"] &&
      length(aws_route_table_association.public) == 2 &&
      length(aws_route_table_association.api) == 1
    )
    error_message = "공개 서브넷 2a·2c 2개와 운영 2a의 사설 서브넷·NAT·EIP 각 1개를 유지해야 합니다."
  }

  assert {
    condition = (
      aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames &&
      aws_vpc.main.tags.Name == "arcamap-vpc" &&
      alltrue([for az, subnet in aws_subnet.public : subnet.availability_zone == az && subnet.tags.Name == "arcamap-public-${az}" && !subnet.map_public_ip_on_launch]) &&
      aws_subnet.api["ap-northeast-2a"].availability_zone == "ap-northeast-2a" &&
      aws_subnet.api["ap-northeast-2a"].tags.Name == "arcamap-api-ap-northeast-2a" &&
      !aws_subnet.api["ap-northeast-2a"].map_public_ip_on_launch
    )
    error_message = "VPC DNS·조회용 이름·공인 IP 자동 할당 금지·운영 AZ 계약을 유지해야 합니다."
  }

  assert {
    condition = (
      aws_nat_gateway.public["ap-northeast-2a"].availability_mode == "zonal" &&
      aws_nat_gateway.public["ap-northeast-2a"].connectivity_type == "public" &&
      aws_nat_gateway.public["ap-northeast-2a"].subnet_id == aws_subnet.public["ap-northeast-2a"].id &&
      aws_nat_gateway.public["ap-northeast-2a"].allocation_id == aws_eip.nat["ap-northeast-2a"].id &&
      one(aws_route_table.api["ap-northeast-2a"].route).cidr_block == "0.0.0.0/0" &&
      one(aws_route_table.api["ap-northeast-2a"].route).nat_gateway_id == aws_nat_gateway.public["ap-northeast-2a"].id &&
      one(aws_route_table.public.route).gateway_id == aws_internet_gateway.main.id
    )
    error_message = "사설 외부 통신은 같은 AZ의 공개 NAT/EIP를, 공개 서브넷은 IGW를 사용해야 합니다."
  }
}

run "security_boundaries" {
  command = plan

  module {
    source = "../../modules/security"
  }

  variables {
    vpc_id = "vpc-00000001"
  }

  override_resource {
    target          = aws_security_group.alb
    override_during = plan
    values          = { id = "sg-00000001" }
  }

  override_resource {
    target          = aws_security_group.api
    override_during = plan
    values          = { id = "sg-00000002" }
  }

  override_resource {
    target          = aws_security_group.dsql_endpoint
    override_during = plan
    values          = { id = "sg-00000003" }
  }

  override_resource {
    target          = aws_security_group.image_builder
    override_during = plan
    values          = { id = "sg-00000004" }
  }

  assert {
    condition = (
      aws_security_group.alb.name == "arcamap-alb" &&
      aws_security_group.api.name == "arcamap-api" &&
      aws_security_group.dsql_endpoint.name == "arcamap-dsql-endpoint" &&
      aws_security_group.image_builder.name == "arcamap-imagebuilder" &&
      aws_security_group.api.id != aws_security_group.image_builder.id &&
      length(aws_security_group.image_builder.ingress) == 0 &&
      length(aws_security_group.image_builder.egress) == 0
    )
    error_message = "운영 API와 빌드 SG를 분리하고 빌드 SG에는 인라인 수신·전체 송신 규칙을 두지 않아야 합니다."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.alb_api.security_group_id == aws_security_group.alb.id &&
      aws_vpc_security_group_egress_rule.alb_api.referenced_security_group_id == aws_security_group.api.id &&
      aws_vpc_security_group_ingress_rule.api_alb.security_group_id == aws_security_group.api.id &&
      aws_vpc_security_group_ingress_rule.api_alb.referenced_security_group_id == aws_security_group.alb.id &&
      alltrue([for rule in [aws_vpc_security_group_egress_rule.alb_api, aws_vpc_security_group_ingress_rule.api_alb] : rule.ip_protocol == "tcp" && rule.from_port == 8080 && rule.to_port == 8080])
    )
    error_message = "ALB와 운영 API 사이의 TCP 8080 통신만 허용하고 빌드 SG를 대상으로 사용하지 않아야 합니다."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.dsql_api.referenced_security_group_id == aws_security_group.api.id &&
      aws_vpc_security_group_ingress_rule.dsql_image_builder.referenced_security_group_id == aws_security_group.image_builder.id &&
      alltrue([for rule in [aws_vpc_security_group_ingress_rule.dsql_api, aws_vpc_security_group_ingress_rule.dsql_image_builder] : rule.security_group_id == aws_security_group.dsql_endpoint.id && rule.ip_protocol == "tcp" && rule.from_port == 5432 && rule.to_port == 5432 && rule.cidr_ipv4 == null && rule.cidr_ipv6 == null]) &&
      aws_vpc_security_group_egress_rule.api_dsql.security_group_id == aws_security_group.api.id &&
      aws_vpc_security_group_egress_rule.image_builder_dsql.security_group_id == aws_security_group.image_builder.id &&
      alltrue([for rule in [aws_vpc_security_group_egress_rule.api_dsql, aws_vpc_security_group_egress_rule.image_builder_dsql] : rule.referenced_security_group_id == aws_security_group.dsql_endpoint.id && rule.ip_protocol == "tcp" && rule.from_port == 5432 && rule.to_port == 5432 && rule.cidr_ipv4 == null && rule.cidr_ipv6 == null])
    )
    error_message = "DSQL TCP 5432는 API·빌드 SG와 Endpoint SG 사이에서만 허용해야 합니다."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.api_https.security_group_id == aws_security_group.api.id &&
      aws_vpc_security_group_egress_rule.image_builder_https.security_group_id == aws_security_group.image_builder.id &&
      alltrue([for rule in [aws_vpc_security_group_egress_rule.api_https, aws_vpc_security_group_egress_rule.image_builder_https] : rule.ip_protocol == "tcp" && rule.from_port == 443 && rule.to_port == 443 && rule.cidr_ipv4 == "0.0.0.0/0"])
    )
    error_message = "운영 API와 빌드의 외부 통신은 HTTPS TCP 443만 허용해야 합니다."
  }
}

run "root_contract" {
  command = plan

  variables {
    notification_email = "operations.alerts+arcamap@example.com"
  }

  override_resource {
    target          = module.security.aws_security_group.alb
    override_during = plan
    values          = { id = "sg-00000001" }
  }

  override_resource {
    target          = module.security.aws_security_group.api
    override_during = plan
    values          = { id = "sg-00000002" }
  }

  override_resource {
    target          = module.security.aws_security_group.dsql_endpoint
    override_during = plan
    values          = { id = "sg-00000003" }
  }

  override_resource {
    target          = module.security.aws_security_group.image_builder
    override_during = plan
    values          = { id = "sg-00000004" }
  }

  assert {
    condition = (
      keys(output.public_subnet_ids) == ["ap-northeast-2a", "ap-northeast-2c"] &&
      keys(output.api_subnet_ids) == ["ap-northeast-2a"] &&
      output.alb_security_group_id == "sg-00000001" &&
      output.api_security_group_id == "sg-00000002" &&
      output.dsql_endpoint_security_group_id == "sg-00000003" &&
      output.image_builder_security_group_id == "sg-00000004"
    )
    error_message = "루트 출력은 공개 2AZ·사설 2a map과 서로 분리된 API·빌드·DSQL Endpoint SG 계약을 제공해야 합니다."
  }

  assert {
    condition = (
      aws_sns_topic.operations.name == "arcamap-operations" &&
      !aws_sns_topic.operations.fifo_topic &&
      aws_sns_topic_subscription.operations.topic_arn == aws_sns_topic.operations.arn &&
      aws_sns_topic_subscription.operations.protocol == "email" &&
      aws_sns_topic_subscription.operations.endpoint == var.notification_email &&
      !aws_sns_topic_subscription.operations.endpoint_auto_confirms &&
      output.notification_topic_arn == "arn:aws:sns:ap-northeast-2:123456789012:arcamap-operations"
    )
    error_message = "필수 이메일 주소로 외부 확인이 필요한 구독을 연결하고 고정 이름의 표준 SNS ARN을 제공해야 합니다."
  }

  assert {
    condition = (
      aws_sns_topic_policy.operations.arn == aws_sns_topic.operations.arn &&
      jsondecode(aws_sns_topic_policy.operations.policy).Version == "2012-10-17" &&
      length(jsondecode(aws_sns_topic_policy.operations.policy).Statement) == 1 &&
      jsondecode(aws_sns_topic_policy.operations.policy).Statement[0].Effect == "Allow" &&
      jsondecode(aws_sns_topic_policy.operations.policy).Statement[0].Principal.Service == "cloudwatch.amazonaws.com" &&
      jsondecode(aws_sns_topic_policy.operations.policy).Statement[0].Action == "sns:Publish" &&
      jsondecode(aws_sns_topic_policy.operations.policy).Statement[0].Resource == aws_sns_topic.operations.arn &&
      jsondecode(aws_sns_topic_policy.operations.policy).Statement[0].Condition == {
        StringEquals = { "aws:SourceAccount" = "123456789012" }
        ArnLike      = { "aws:SourceArn" = "arn:aws:cloudwatch:ap-northeast-2:123456789012:alarm:arcamap-*" }
      }
    )
    error_message = "CloudWatch 발행 허용은 현재 토픽과 동일 계정·리전의 arcamap 경보로 제한해야 합니다."
  }
}

run "reject_empty_notification_email" {
  command = plan

  variables {
    notification_email = ""
  }

  expect_failures = [var.notification_email]
}

run "reject_malformed_notification_email" {
  command = plan

  variables {
    notification_email = "operations..alerts@-example.com"
  }

  expect_failures = [var.notification_email]
}
