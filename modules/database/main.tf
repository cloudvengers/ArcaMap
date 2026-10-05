locals {
  region = "ap-northeast-2"
  host   = "${aws_dsql_cluster.main.identifier}.${reverse(split(".", aws_dsql_cluster.main.vpc_endpoint_service_name))[0]}.${local.region}.on.aws"
}

resource "aws_dsql_cluster" "main" {
  region                      = local.region
  deletion_protection_enabled = true
  force_destroy               = false
  kms_encryption_key          = "AWS_OWNED_KMS_KEY"

  tags = { Name = "arcamap-dsql" }

  lifecycle {
    postcondition {
      condition     = can(regex("^com\\.amazonaws\\.ap-northeast-2\\.dsql-[a-z0-9-]+$", self.vpc_endpoint_service_name))
      error_message = "DSQL 접속 Endpoint에는 대상 클러스터의 GetVpcEndpointServiceName 결과가 필요합니다."
    }
  }
}

resource "aws_vpc_endpoint" "database" {
  region              = local.region
  vpc_id              = var.vpc_id
  service_name        = aws_dsql_cluster.main.vpc_endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.endpoint_subnet_id]
  security_group_ids  = [var.dsql_endpoint_security_group_id]
  private_dns_enabled = true

  tags = { Name = "arcamap-dsql" }
}
