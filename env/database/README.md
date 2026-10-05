# 데이터베이스 환경

`database` 환경은 서울 리전의 Aurora DSQL 클러스터, VPC 엔드포인트와 연결 수 경보를 구성합니다. [database 모듈](../../modules/database/README.md)과 [cloudwatch-alarm 모듈](../../modules/cloudwatch-alarm/README.md)을 사용합니다.

## 클러스터와 네트워크

| 항목 | 설정 |
|---|---|
| 리전 | `ap-northeast-2` |
| 클러스터 이름 태그 | `arcamap-dsql` |
| 암호화 | AWS 소유 KMS 키 |
| 삭제 방지 | 활성화 |
| VPC | `arcamap-vpc` |
| 엔드포인트 서브넷 | `arcamap-api-ap-northeast-2a` |
| 엔드포인트 보안 그룹 | `arcamap-dsql-endpoint` |
| Private DNS | 활성화 |
| 데이터베이스·포트 | `postgres`, TCP `5432` |
| 인증 | IAM |

[네트워크 환경](../network/README.md)의 VPC, 사설 서브넷과 보안 그룹을 이름·태그로 조회합니다. API는 VPC 엔드포인트를 통해 클러스터에 접속합니다.

## 연결 수 경보

경보 이름은 `arcamap-dsql-cluster-connections`입니다. `AWS/Usage`의 `ResourceCount` 지표에서 해당 클러스터의 `ClusterConnectionCount`를 평가합니다.

| 항목 | 설정 |
|---|---|
| 통계 | 평균 |
| 임계값 | `dsql_cluster_connection_quota` 입력값의 80% 이상 |
| 평가 | 1분 구간 3회 연속 |
| 누락 데이터 처리 | `missing` |
| 알림 토픽 | `arcamap-operations` |

`dsql_cluster_connection_quota`의 기본값은 10,000입니다. 이 값을 사용하면 경보 임계값은 8,000입니다. `ALARM`, `OK`, `INSUFFICIENT_DATA` 상태 전환을 SNS로 알립니다.

## 출력

`database` 출력은 클러스터 ID·ARN, 리전, 접속·인증 호스트, 데이터베이스 이름·포트와 VPC 엔드포인트 정보를 반환합니다. API에는 접속 정보를, 모니터링에는 클러스터 ID를, 백업에는 클러스터 ARN을 전달합니다.

모듈 연결은 [main.tf](main.tf)에, 경보는 [monitoring.tf](monitoring.tf)에 정의합니다. 입력과 출력은 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
