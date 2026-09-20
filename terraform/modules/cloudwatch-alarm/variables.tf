variable "alarm" {
  description = "서비스별 CloudWatch 단일 지표 경보 설정. 알림 동작은 비활성 상태로 유지합니다."
  type = object({
    namespace           = string
    metric_name         = string
    dimensions          = map(string)
    statistic           = string
    threshold           = number
    comparison_operator = string
    period              = number
    datapoints_to_alarm = number
    evaluation_periods  = number
    treat_missing_data  = string
    description         = optional(string)
    unit                = optional(string)
  })
  nullable = false

  validation {
    condition = (
      can(regex("\\S", var.alarm.namespace)) &&
      can(regex("\\S", var.alarm.metric_name)) &&
      contains(["SampleCount", "Average", "Sum", "Minimum", "Maximum"], var.alarm.statistic) &&
      contains(["GreaterThanOrEqualToThreshold", "GreaterThanThreshold", "LessThanThreshold", "LessThanOrEqualToThreshold"], var.alarm.comparison_operator) &&
      contains(["breaching", "notBreaching", "ignore", "missing"], var.alarm.treat_missing_data)
    )
    error_message = "지표·네임스페이스를 지정하고 지원하는 통계·비교 연산·누락 데이터 처리 값을 사용해야 합니다."
  }

  validation {
    condition = (
      var.alarm.period >= 60 && var.alarm.period % 60 == 0 &&
      var.alarm.datapoints_to_alarm >= 1 && floor(var.alarm.datapoints_to_alarm) == var.alarm.datapoints_to_alarm &&
      var.alarm.evaluation_periods >= var.alarm.datapoints_to_alarm && floor(var.alarm.evaluation_periods) == var.alarm.evaluation_periods
    )
    error_message = "현재 서비스 경보의 주기는 60초 배수이며, 평가 횟수와 경보 횟수는 양의 정수이고 경보 횟수는 평가 횟수 이하여야 합니다."
  }
}

variable "name" {
  description = "CloudWatch 경보의 고유 이름."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 255 && var.name == trimspace(var.name)
    error_message = "경보 이름은 앞뒤 공백 없는 1~255자여야 합니다."
  }
}
