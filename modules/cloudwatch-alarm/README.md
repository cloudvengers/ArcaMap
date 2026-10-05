# CloudWatch 지표 경보

`cloudwatch-alarm` 모듈은 지표 경보 1개를 구성합니다. [API 환경](../../env/api/README.md)과 [데이터베이스 환경](../../env/database/README.md)에서 사용합니다.

## 평가와 알림

경보는 지정한 기간의 지표 통계를 임계값과 비교합니다. 전체 평가 구간 `evaluation_periods` 중 조건을 충족한 구간이 `datapoints_to_alarm`에 도달하면 `ALARM` 상태로 전환합니다. 누락 데이터의 처리는 `treat_missing_data`로 지정합니다.

경보의 `ALARM`, `OK`, `INSUFFICIENT_DATA` 상태 전환을 모두 입력한 SNS 토픽으로 알립니다.

## 입력

| 입력 | 내용 |
|---|---|
| `name` | 경보 이름 |
| `alarm` | 지표와 평가 조건 객체 |
| `notification_topic_arn` | 알림을 전달할 SNS 토픽 ARN |

`alarm` 객체의 필드는 다음과 같습니다.

| 필드 | 내용 |
|---|---|
| `namespace`, `metric_name`, `dimensions` | 지표 네임스페이스, 이름과 차원 |
| `statistic` | 평가할 통계 |
| `threshold`, `comparison_operator` | 임계값과 비교 연산자 |
| `period` | 평가 구간의 길이. 60초 이상의 60초 배수 |
| `evaluation_periods` | 전체 평가 구간 수 |
| `datapoints_to_alarm` | 경보에 필요한 조건 충족 구간 수 |
| `treat_missing_data` | 누락 데이터 처리 방식 |
| `description`, `unit` | 선택 입력인 설명과 단위 |

## 출력

`name`과 `arn` 출력은 경보 이름과 ARN을 반환합니다. 입력과 출력의 구조는 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
