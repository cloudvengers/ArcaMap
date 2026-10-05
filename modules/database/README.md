# Aurora DSQL

`database` 모듈은 서울 리전의 Aurora DSQL 클러스터와 접속용 VPC 엔드포인트를 구성합니다. [데이터베이스 환경](../../env/database/README.md)에서 사용합니다.

## 클러스터와 접속

| 항목 | 설정 |
|---|---|
| 리전 | `ap-northeast-2` |
| 클러스터 이름 태그 | `arcamap-dsql` |
| 암호화 키 | AWS 소유 KMS 키 |
| 삭제 방지 | 활성화 |
| 강제 삭제 | 비활성화 |
| 데이터베이스 이름 | `postgres` |
| 접속 포트 | TCP `5432` |
| 인증 | IAM |

VPC 엔드포인트는 입력한 사설 서브넷에 인터페이스 방식으로 구성합니다. 클러스터의 엔드포인트 서비스를 연결하고 Private DNS를 활성화합니다. 접속에는 `host`와 `auth_host`의 동일한 호스트 이름을 사용합니다.

## 입력

| 입력 | 내용 |
|---|---|
| `vpc_id` | VPC ID |
| `endpoint_subnet_id` | VPC 엔드포인트를 배치할 서브넷 ID |
| `dsql_endpoint_security_group_id` | VPC 엔드포인트 보안 그룹 ID |

## 출력

`database` 객체는 다음 값을 반환합니다.

| 필드 | 내용 |
|---|---|
| `cluster_id`, `cluster_arn` | 클러스터 ID와 ARN |
| `region` | 리전 |
| `host`, `auth_host` | 접속·인증 호스트 이름 |
| `dbname`, `port` | 데이터베이스 이름과 포트 |
| `vpc_endpoint_id` | VPC 엔드포인트 ID |
| `vpc_endpoint_service_name` | 클러스터의 엔드포인트 서비스 이름 |

리소스는 [main.tf](main.tf)에, 입력과 출력은 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
