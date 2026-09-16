# CloudWatch 지표 경보

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 네임스페이스 | 서비스별 지표 구분 | AWS/EC2·RDS·ApplicationELB·AutoScaling |
| 지표 차원 | 지표가 속한 자원의 식별값 | ASG 이름·ALB suffix·DB 식별자 |
| 통계 | 주기 안의 지표 집계 방식 | Average·Minimum·Maximum·Sum |
| M/N 평가 | 최근 N개 구간 중 M개 이상 위반 시 경보 | 2/3·3/3·1/1 |
| 누락 데이터 처리 | 지표가 없는 구간의 평가 방법 | 5xx는 `notBreaching`, 나머지는 `missing` |
| 경보 액션 | 상태 변경 시 실행할 알림·작업 | 현재 비활성화 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 모듈 | `terraform/modules/cloudwatch-alarm` |
| 호출 루트 | was 6개, db 기본 3개 |
| `name` | `arcamap-` 접두사, 앞뒤 공백 없는 1~255자 |
| `alarm` | 단일 지표 경보 설정 객체 |
| `actions_enabled` | false |
| 상태별 액션 | ALARM·OK·INSUFFICIENT_DATA 모두 빈 목록 |
| 출력 | 없음 |

| `alarm` 필드 | 내용·조건 |
|---|---|
| `namespace`, `metric_name` | 지표 서비스·이름 |
| `dimensions` | 자원 식별값의 문자열 맵 |
| `statistic` | SampleCount·Average·Sum·Minimum·Maximum |
| `threshold`, `comparison_operator` | 임계값, 이상·초과·미만·이하 비교 |
| `period` | 60초 이상·60초 배수 |
| `datapoints_to_alarm`, `evaluation_periods` | M·N, 양의 정수이며 M≤N |
| `treat_missing_data` | breaching·notBreaching·ignore·missing |
| `description`, `unit` | 선택 입력, 기본 null |

## 현재 경보

이름 접두사: `arcamap-`.

| 루트 | 이름 | 지표·통계 | 임계값 | 주기 | M/N |
|---|---|---|---|---|---|
| was | `asg-inservice` | GroupInServiceInstances·Minimum | 2대 미만 | 60초 | 2/3 |
| was | `ec2-status-check` | StatusCheckFailed·Maximum | 1 이상 | 60초 | 2/3 |
| was | `ec2-cpu` | CPUUtilization·Average | 80% 이상 | 300초 | 3/3 |
| was | `alb-healthy-hosts` | HealthyHostCount·Minimum | 2대 미만 | 60초 | 2/3 |
| was | `alb-5xx` | HTTPCode_ELB_5XX_Count·Sum | 5건 이상 | 300초 | 1/1 |
| was | `api-5xx` | HTTPCode_Target_5XX_Count·Sum | 5건 이상 | 300초 | 1/1 |
| db | `rds-cpu` | CPUUtilization·Average | 80% 이상 | 300초 | 3/3 |
| db | `rds-free-memory` | FreeableMemory·Minimum | 512 MiB 미만 | 300초 | 3/3 |
| db | `rds-free-storage` | FreeStorageSpace·Minimum | 5 GiB 미만 | 300초 | 1/1 |

| 추가 설정 | 값 |
|---|---|
| 5xx 누락 데이터 | `notBreaching` |
| 그 밖의 누락 데이터 | `missing` |
| DB 연결 수 경보 | `db_max_connections=null`로 미생성 |
| 연결 수 입력 시 | `rds-database-connections`, Average, 최대 연결 수의 80% 이상, 60초·3/3, Count |
| CPU 확장 정책 | ASG 평균 CPU 50%, 위 80% 경보와 별도 |

ALB 5xx는 ALB가 생성한 오류, Target 5xx는 WAS가 반환한 오류입니다.

## 설정 변경·조회

| 작업 | 처리 |
|---|---|
| 임계값·주기 변경 | 해당 루트 `main.tf`의 경보 설정 변경 후 plan·apply |
| 연결 수 경보 생성 | DB에서 `SHOW max_connections;` 조회 → db 입력에 결과 지정 → plan·apply |
| 알림 수신 | 현재 연결 없음. 경보 상태 평가만 수행 |

```bash
aws cloudwatch describe-alarms \
  --region ap-northeast-2 --alarm-name-prefix arcamap- \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason,Actions:ActionsEnabled,Dimensions:Dimensions}'
```

## 상태별 대응

| 상태·증상 | 점검 순서 |
|---|---|
| `OK` | 해당 지표가 설정된 경보 조건을 위반하지 않음 |
| `ALARM` | 임계값·지표 추이·대상 자원 상태 확인 |
| `INSUFFICIENT_DATA` | 지표 차원·수집 주기·실제 데이터 유무 확인 |
| 정상 인스턴스·대상 부족 | ASG 활동 → EC2 상태 → API 로그 → ALB 대상 상태 |
| API 5xx | API 로그 → `/health/db` → RDS 상태 |
| DB 메모리·저장 공간 부족 | 지표 추이 → 연결·쿼리·용량 확인 |

설정 확인 기준: 기본 경보 9개, 액션 비활성화, 경보별 임계값·주기·차원이 현재 구성과 일치.
