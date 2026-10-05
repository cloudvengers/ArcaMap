# 통합 모니터링

`monitoring` 환경은 API, DSQL과 콘텐츠 전달 지표를 모아 보는 CloudWatch 대시보드 `arcamap-operations`를 구성합니다. 기본 조회 범위는 최근 7일이며 지표 주기는 300초입니다.

## 연결 대상

| 대상 | 조회 이름·조건 |
|---|---|
| API ASG | `arcamap-api` |
| API ALB | `arcamap-api` |
| 대상 그룹 | API ASG에 연결된 대상 그룹 1개 |
| API WAF | `arcamap-api`, `REGIONAL` |
| CloudFront WAF | `CreatedByCloudFront-609132c8`, `CLOUDFRONT`, `us-east-1` |
| DSQL | `dsql_cluster_identifier`로 입력한 클러스터 ID |

`dsql_cluster_identifier`에는 [데이터베이스 환경](../database/README.md)의 `database.cluster_id`를 전달합니다. 입력값은 [terraform.tfvars](terraform.tfvars)에 지정합니다.

## 로그

다음 접두사별로 로그 그룹 1개를 조회합니다.

| 용도 | 로그 그룹 접두사 | 리전 |
|---|---|---|
| ALB | `/aws/vendedlogs/elb/arcamap-api` | `ap-northeast-2` |
| 시스템 | `/arcamap/ec2/system` | `ap-northeast-2` |
| API WAF | `aws-waf-logs-arcamap-api` | `ap-northeast-2` |
| CloudFront WAF | `aws-waf-logs-CloudFrontDistribution-` | `us-east-1` |

대시보드는 ALB 로그와 시스템 오류 로그를 각각 최근 100건까지 표시합니다. WAF 로그는 5분 구간별 규칙별 차단 건수로 표시합니다.

## 지표와 경보

지표 패널은 ASG 용량, EC2 CPU·메모리, ALB 응답, WAF 요청과 DSQL 처리량·지연·사용량을 표시합니다.

경보 패널은 다음 8개 경보를 표시합니다. API 경보는 [API 환경](../api/README.md)에서, DSQL 경보는 데이터베이스 환경에서 관리합니다.

| 경보 | 대상 |
|---|---|
| `arcamap-asg-inservice` | 실행 인스턴스 수 |
| `arcamap-ec2-status-check` | EC2 상태 검사 |
| `arcamap-ec2-cpu` | CPU 사용률 |
| `arcamap-ec2-memory` | 메모리 사용률 |
| `arcamap-alb-healthy-hosts` | ALB 정상 대상 수 |
| `arcamap-alb-5xx` | ALB 5xx 응답 |
| `arcamap-api-5xx` | 대상 5xx 응답 |
| `arcamap-dsql-cluster-connections` | DSQL 연결 수 |

패널별 지표와 조회 설정은 [대시보드 모듈](../../modules/cloudwatch-dashboard/README.md)에 정의합니다.

## 출력

`dashboard` 출력은 대시보드 이름과 ARN을 반환합니다. 리소스 조회는 [data.tf](data.tf)에, 대시보드 연결은 [main.tf](main.tf)에 정의합니다.
