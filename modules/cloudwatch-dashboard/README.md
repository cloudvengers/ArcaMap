# CloudWatch 대시보드

`cloudwatch-dashboard` 모듈은 API, 데이터베이스와 콘텐츠 전달 상태를 모아 보는 대시보드를 구성합니다. [모니터링 환경](../../env/monitoring/README.md)에서 사용합니다.

기본 이름은 `arcamap-operations`입니다. 기본 조회 범위는 최근 7일이며 지표 주기는 300초입니다.

## 표시 항목

대시보드는 지표 패널 18개, 로그 패널 4개와 경보 패널 1개로 구성합니다.

| 대상 | 주요 지표 |
|---|---|
| ASG | 목표 인스턴스 수, 실행 인스턴스 수 |
| EC2 | CPU 사용률, 메모리 사용률, 가용 메모리 |
| ALB | 정상 대상 수, 요청 수, 응답 시간, 4xx·5xx 응답 수 |
| API·CloudFront WAF | 허용·차단 요청 수 |
| DSQL | 읽기·전체 트랜잭션, 시간 초과, 동시성 충돌, 커밋 지연 |
| DSQL 사용량 | 읽기·쓰기 바이트, 연산 시간, 저장 용량, 연결 수, DPU |

CloudFront WAF 지표는 `us-east-1`에서 조회합니다. 나머지 지표는 `region` 입력으로 지정한 리전에서 조회하며 기본값은 `ap-northeast-2`입니다.

## 로그와 경보

| 로그 패널 | 조회 내용 |
|---|---|
| ALB | 최근 로그 100건 |
| 시스템 | 오류 관련 로그 100건 |
| API WAF | 5분 구간별 규칙별 차단 건수 |
| CloudFront WAF | 5분 구간별 규칙별 차단 건수 |

경보 패널은 `alarm_arns`에 지정한 경보의 상태를 표시합니다.

## 입력과 출력

| 입력 | 내용 |
|---|---|
| `name`, `region` | 대시보드 이름과 기본 리전 |
| `asg_name` | API ASG 이름 |
| `alb_arn_suffix`, `target_group_arn_suffix` | ALB와 대상 그룹의 ARN 접미사 |
| `dsql_cluster_identifier` | DSQL 클러스터 ID |
| `waf_metric_names` | API·CloudFront WAF 지표 이름 |
| `log_groups` | `alb`, `system`, `waf_api`, `waf_cloudfront` 로그 그룹 이름 |
| `alarm_arns` | 표시할 경보 ARN 목록 |

`dashboard` 출력은 대시보드 이름과 ARN을 반환합니다. 입력과 출력의 구조는 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
