resource "aws_cloudwatch_metric_alarm" "main" {
  alarm_name                = var.name
  alarm_description         = var.alarm.description
  namespace                 = var.alarm.namespace
  metric_name               = var.alarm.metric_name
  dimensions                = var.alarm.dimensions
  statistic                 = var.alarm.statistic
  threshold                 = var.alarm.threshold
  comparison_operator       = var.alarm.comparison_operator
  period                    = var.alarm.period
  datapoints_to_alarm       = var.alarm.datapoints_to_alarm
  evaluation_periods        = var.alarm.evaluation_periods
  treat_missing_data        = var.alarm.treat_missing_data
  unit                      = var.alarm.unit
  actions_enabled           = false
  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}
