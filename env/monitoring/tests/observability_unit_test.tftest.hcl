# AWS 요청 없이 terraform -chdir=env/monitoring test로 실행합니다.
mock_provider "aws" {
  override_during = plan
}

run "alarm_notifications_and_dsql_contract" {
  command = plan

  module {
    source = "../../modules/cloudwatch-alarm"
  }

  variables {
    name                   = "arcamap-dsql-cluster-connections"
    notification_topic_arn = "arn:aws:sns:ap-northeast-2:123456789012:arcamap-operations"
    alarm = {
      namespace           = "AWS/Usage"
      metric_name         = "ResourceCount"
      unit                = "None"
      statistic           = "Average"
      threshold           = 8000
      comparison_operator = "GreaterThanOrEqualToThreshold"
      period              = 60
      datapoints_to_alarm = 3
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions = {
        Type       = "Resource"
        Class      = "None"
        Resource   = "ClusterConnectionCount"
        ResourceId = "cluster/0123456789abcdefghijklmnop"
        Service    = "AuroraDSQL"
      }
    }
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.main.actions_enabled &&
      toset(aws_cloudwatch_metric_alarm.main.alarm_actions) == toset([var.notification_topic_arn]) &&
      toset(aws_cloudwatch_metric_alarm.main.ok_actions) == toset([var.notification_topic_arn]) &&
      toset(aws_cloudwatch_metric_alarm.main.insufficient_data_actions) == toset([var.notification_topic_arn])
    )
    error_message = "직접 만든 경보는 활성 상태로 ALARM·OK·INSUFFICIENT_DATA 모두 같은 SNS에 알려야 합니다."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.main.dimensions == var.alarm.dimensions &&
      aws_cloudwatch_metric_alarm.main.threshold == 8000 &&
      aws_cloudwatch_metric_alarm.main.unit == "None" &&
      alltrue([for field, value in {
        namespace           = "\"AWS/Usage\""
        metric_name         = "\"ResourceCount\""
        unit                = "\"None\""
        statistic           = "\"Average\""
        comparison_operator = "\"GreaterThanOrEqualToThreshold\""
        period              = "60"
        datapoints_to_alarm = "3"
        evaluation_periods  = "3"
        treat_missing_data  = "\"missing\""
        Type                = "\"Resource\""
        Class               = "\"None\""
        Resource            = "\"ClusterConnectionCount\""
        Service             = "\"AuroraDSQL\""
      } : can(regex("${field}\\s*=\\s*${value}(\\s|$)", file("${path.module}/../../env/database/monitoring.tf")))]) &&
      can(regex("threshold\\s*=\\s*var\\.dsql_cluster_connection_quota\\s*\\*\\s*0\\.8(\\s|$)", file("${path.module}/../../env/database/monitoring.tf"))) &&
      strcontains(file("${path.module}/../../env/database/monitoring.tf"), "\"cluster/$${module.database.database.cluster_id}\"")
    )
    error_message = "실제 DB 구성은 AWS/Usage 연결 수 차원·쿼터80%·60초평균3회·missing 조건을 유지해야 합니다."
  }
}

run "dashboard_dsql_metrics_and_layout" {
  command = plan

  module {
    source = "../../modules/cloudwatch-dashboard"
  }

  variables {
    asg_name                = "arcamap-api"
    alb_arn_suffix          = "app/arcamap-api/0000000000000000"
    target_group_arn_suffix = "targetgroup/arcamap-api/0000000000000000"
    dsql_cluster_identifier = "0123456789abcdefghijklmnop"
    alarm_arns              = ["arn:aws:cloudwatch:ap-northeast-2:123456789012:alarm:arcamap-dsql-cluster-connections"]
    log_groups = {
      alb            = "/aws/vendedlogs/elb/arcamap-api"
      system         = "/arcamap/ec2/system"
      waf_api        = "aws-waf-logs-arcamap-api"
      waf_cloudfront = "aws-waf-logs-CloudFrontDistribution-MOCK"
    }
    waf_metric_names = {
      api        = "arcamap-api"
      cloudfront = "CreatedByCloudFront-609132c8"
    }
  }

  assert {
    condition = toset([for metric in flatten([for panel in slice(local.dsql_metric_panels, 0, 6) : panel.metrics]) : metric.expression]) == toset([
      for metric, statistic in {
        ReadOnlyTransactions = "Sum"
        TotalTransactions    = "Sum"
        QueryTimeouts        = "Sum"
        OccConflicts         = "Sum"
        CommitLatency        = "Average"
        BytesRead            = "Sum"
        BytesWritten         = "Sum"
        ComputeTime          = "Sum"
        ClusterStorageSize   = "Average"
      } : "SEARCH('{AWS/AuroraDSQL} MetricName=\"${metric}\" \"${var.dsql_cluster_identifier}\"', '${statistic}', 300)"
    ])
    error_message = "DSQL 검색은 namespace와 지표명·전체 cluster ID를 정확일치로 제한해 다른 클러스터를 선택하지 않아야 합니다."
  }

  assert {
    condition = (
      local.dsql_metric_panels[6].metrics[0] == ["AWS/Usage", "ResourceCount", "Type", "Resource", "Resource", "ClusterConnectionCount", "ResourceId", "cluster/${var.dsql_cluster_identifier}", "Service", "AuroraDSQL", "Class", "None"] &&
      toset([for metric in local.dsql_metric_panels[7].metrics : metric[1]]) == toset(["ReadDPU", "WriteDPU", "ComputeDPU", "TotalDPU"]) &&
      alltrue([for metric in local.dsql_metric_panels[7].metrics : metric[0] == "AWS/AuroraDSQL" && metric[2] == "ClusterId" && metric[3] == var.dsql_cluster_identifier && metric[4].stat == "Sum"])
    )
    error_message = "연결 수의 ResourceId=cluster/<id>·Class=None과 DPU의 ClusterId=<id>를 구분하고 네 가지 DPU를 5분 합계로 표시해야 합니다."
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).start == "-P7D" &&
      jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).periodOverride == "inherit" &&
      tolist(jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).widgets[0].properties.alarms) == var.alarm_arns &&
      alltrue([for widget in jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).widgets : widget.properties.period == 300 if widget.type == "metric"]) &&
      min([for widget in jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).widgets : widget.y if widget.type == "log"]...) >= max([for widget in jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).widgets : widget.y + widget.height if widget.type == "metric"]...) &&
      alltrue([for widget in jsondecode(aws_cloudwatch_dashboard.main.dashboard_body).widgets : widget.properties.region == "us-east-1" if strcontains(widget.properties.title, "CloudFront")])
    )
    error_message = "7일·300초 조회와 CF us-east-1을 유지하고 로그 위젯을 모든 지표 행 아래 배치해야 합니다."
  }
}
