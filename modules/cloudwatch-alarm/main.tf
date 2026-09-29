resource "aws_cloudwatch_metric_alarm" "main" {             # CloudWatch 지표 경보 정의
  alarm_name                = var.name                      # CloudWatch 경보 이름
  alarm_description         = var.alarm.description         # 경보 판단 기준 설명
  namespace                 = var.alarm.namespace           # CloudWatch 지표 네임스페이스
  metric_name               = var.alarm.metric_name         # 감시하거나 수집할 지표 이름
  dimensions                = var.alarm.dimensions          # 경보에서 감시할 지표 차원
  statistic                 = var.alarm.statistic           # 경보 대상 지표의 집계 방식
  threshold                 = var.alarm.threshold           # 경보를 발생시킬 임계값
  comparison_operator       = var.alarm.comparison_operator # 측정값과 임계값의 비교 방식
  period                    = var.alarm.period              # 지표 집계·경보 평가 주기(초)
  datapoints_to_alarm       = var.alarm.datapoints_to_alarm # 경보에 필요한 임계값 위반 구간 수
  evaluation_periods        = var.alarm.evaluation_periods  # 경보를 평가할 최근 구간 수
  treat_missing_data        = var.alarm.treat_missing_data  # 지표가 없을 때 경보 상태 판단 방식
  unit                      = var.alarm.unit                # 지표 측정 단위
  actions_enabled           = false                         # 경보 상태 변경 시 동작 실행 여부
  alarm_actions             = []                            # 경보 상태 진입 시 실행할 동작
  ok_actions                = []                            # 정상 상태 복귀 시 실행할 동작
  insufficient_data_actions = []                            # 데이터 부족 상태에서 실행할 동작
}                                                           # 설정 묶음 끝
