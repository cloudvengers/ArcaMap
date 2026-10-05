output "database" {
  description = "서울 DSQL 클러스터와 PrivateLink 접속·IAM 토큰 생성에 사용하는 동일 호스트."
  value = {
    cluster_id                = aws_dsql_cluster.main.identifier
    cluster_arn               = aws_dsql_cluster.main.arn
    region                    = local.region
    host                      = local.host
    auth_host                 = local.host
    dbname                    = "postgres"
    port                      = 5432
    vpc_endpoint_id           = aws_vpc_endpoint.database.id
    vpc_endpoint_service_name = aws_dsql_cluster.main.vpc_endpoint_service_name
  }
}
