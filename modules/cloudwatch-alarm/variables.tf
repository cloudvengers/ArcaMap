variable "alarm" {                                                  # 입력 변수: 서비스별 CloudWatch 단일 지표 경보 설정
  description = "서비스별 CloudWatch 단일 지표 경보 설정. 상태 전환 3종을 SNS로 알립니다." # 입력값의 의미와 사용 범위
  type = object({                                                   # 입력값의 자료형
    namespace           = string                                    # CloudWatch 지표 네임스페이스
    metric_name         = string                                    # 감시하거나 수집할 지표 이름
    dimensions          = map(string)                               # 경보에서 감시할 지표 차원
    statistic           = string                                    # 경보 대상 지표의 집계 방식
    threshold           = number                                    # 경보를 발생시킬 임계값
    comparison_operator = string                                    # 측정값과 임계값의 비교 방식
    period              = number                                    # 지표 집계·경보 평가 주기(초)
    datapoints_to_alarm = number                                    # 경보에 필요한 임계값 위반 구간 수
    evaluation_periods  = number                                    # 경보를 평가할 최근 구간 수
    treat_missing_data  = string                                    # 지표가 없을 때 경보 상태 판단 방식
    description         = optional(string)                          # 입력값의 의미와 사용 범위
    unit                = optional(string)                          # 지표 측정 단위
  })                                                                # 설정 묶음 끝
  nullable = false                                                  # null 입력 허용 여부

  validation {                                                                                                                                                 # 입력값 검증 규칙
    condition = (                                                                                                                                              # 허용할 입력값 검증 조건
      can(regex("\\S", var.alarm.namespace)) &&                                                                                                                # 지표 네임스페이스가 비어 있지 않은지 검사
      can(regex("\\S", var.alarm.metric_name)) &&                                                                                                              # 지표 이름이 비어 있지 않은지 검사
      contains(["SampleCount", "Average", "Sum", "Minimum", "Maximum"], var.alarm.statistic) &&                                                                # CloudWatch가 지원하는 집계 방식인지 검사
      contains(["GreaterThanOrEqualToThreshold", "GreaterThanThreshold", "LessThanThreshold", "LessThanOrEqualToThreshold"], var.alarm.comparison_operator) && # 지원하는 임계값 비교 방식인지 검사
      contains(["breaching", "notBreaching", "ignore", "missing"], var.alarm.treat_missing_data)                                                               # 지원하는 데이터 누락 처리 방식인지 검사
    )                                                                                                                                                          # 설정 묶음 끝
    error_message = "지표·네임스페이스를 지정하고 지원하는 통계·비교 연산·누락 데이터 처리 값을 사용해야 합니다."                                                                                     # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                            # 설정 묶음 끝

  validation {                                                                                                                             # 입력값 검증 규칙
    condition = (                                                                                                                          # 허용할 입력값 검증 조건
      var.alarm.period >= 60 && var.alarm.period % 60 == 0 &&                                                                              # 평가 주기가 60초 이상의 분 단위인지 검사
      var.alarm.datapoints_to_alarm >= 1 && floor(var.alarm.datapoints_to_alarm) == var.alarm.datapoints_to_alarm &&                       # 위반 구간 수가 1 이상의 정수인지 검사
      var.alarm.evaluation_periods >= var.alarm.datapoints_to_alarm && floor(var.alarm.evaluation_periods) == var.alarm.evaluation_periods # 평가 구간 수가 위반 구간 수 이상의 정수인지 검사
    )                                                                                                                                      # 설정 묶음 끝
    error_message = "현재 서비스 경보의 주기는 60초 배수이며, 평가 횟수와 경보 횟수는 양의 정수이고 경보 횟수는 평가 횟수 이하여야 합니다."                                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                        # 설정 묶음 끝
}                                                                                                                                          # 설정 묶음 끝

variable "name" {                       # 입력 변수: CloudWatch 경보의 고유 이름
  description = "CloudWatch 경보의 고유 이름." # 입력값의 의미와 사용 범위
  type        = string                  # 입력값의 자료형
  nullable    = false                   # null 입력 허용 여부

  validation {                                                                                          # 입력값 검증 규칙
    condition     = length(var.name) >= 1 && length(var.name) <= 255 && var.name == trimspace(var.name) # 허용할 입력값 검증 조건
    error_message = "경보 이름은 앞뒤 공백 없는 1~255자여야 합니다."                                                     # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                     # 설정 묶음 끝
}                                                                                                       # 설정 묶음 끝

variable "notification_topic_arn" {
  description = "ALARM·OK·INSUFFICIENT_DATA 상태 전환을 알릴 SNS 표준 토픽 ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:(aws|aws-cn|aws-us-gov):sns:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]+$", var.notification_topic_arn))
    error_message = "알림 대상은 SNS 표준 토픽 ARN이어야 합니다."
  }
}
