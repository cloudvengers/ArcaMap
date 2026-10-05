module "database" {
  source = "../../modules/database"

  vpc_id                          = data.aws_vpc.main.id
  endpoint_subnet_id              = data.aws_subnet.api.id
  dsql_endpoint_security_group_id = data.aws_security_group.dsql_endpoint.id
}
