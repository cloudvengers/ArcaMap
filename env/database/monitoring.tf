data "aws_sns_topic" "operations" {
  name = "arcamap-operations"
}

module "db_connections" {
  source = "../../modules/cloudwatch-alarm"

  name                   = "arcamap-dsql-cluster-connections"
  notification_topic_arn = data.aws_sns_topic.operations.arn
  alarm = {
    description         = "DSQL 클러스터의 1분 평균 연결 수가 적용된 연결 쿼터의 80% 이상인 상태가 3회 연속 지속됨."
    namespace           = "AWS/Usage"
    metric_name         = "ResourceCount"
    unit                = "None"
    statistic           = "Average"
    threshold           = var.dsql_cluster_connection_quota * 0.8
    comparison_operator = "GreaterThanOrEqualToThreshold"
    period              = 60
    datapoints_to_alarm = 3
    evaluation_periods  = 3
    treat_missing_data  = "missing"
    dimensions = {
      Type       = "Resource"
      Class      = "None"
      Resource   = "ClusterConnectionCount"
      ResourceId = "cluster/${module.database.database.cluster_id}"
      Service    = "AuroraDSQL"
    }
  }
}
