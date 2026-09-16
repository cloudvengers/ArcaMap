# 운영 DB 적용

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| Multi-AZ | 다른 AZ의 대기 인스턴스로 장애 대응 | 운영 PostgreSQL |
| DB 서브넷 그룹 | RDS 배치에 사용할 서브넷 집합 | 2a·2c DB 서브넷 |
| Ephemeral 변수 | state·plan에 값을 저장하지 않는 입력 | `db_password` |
| Write-only 인수 | 비밀값 쓰기 전용 인수 | `password_wo`, 버전 `1` |
| 연결 수 경보 | 실제 최대 연결 수 대비 사용량 감시 | 최대값 입력 시 80% 기준 생성 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 실행 위치 | `/root/protomaps/terraform/env/db` |
| Terraform / AWS Provider | `1.16.1` / `6.63.0` |
| 리전 / State | `ap-northeast-2` / 루트의 `terraform.tfstate` |
| RDS 식별자 / DB | `arcamap-postgres` / `arcamap` |
| `db_engine_version` | `17.11` |
| `db_instance_class` | `db.t4g.medium` |
| `db_allocated_storage` / `db_max_allocated_storage` | 20 / 100 GiB |
| `db_username` | `<DB_USERNAME>` |
| `db_password` | sensitive·ephemeral 입력, WAS와 같은 운영 비밀번호 |
| `db_final_snapshot_identifier` | `arcamap-postgres-final` |
| `log_retention_days` | 30일 |
| `db_max_connections` | 기본 `null`, 연결 수 경보 미생성 |

일반 입력은 `terraform.tfvars` 사용. 비밀번호를 포함한 파일 권한은 `600`. 같은 변수를 파일과 `TF_VAR_*`에 모두 지정하면 파일 값이 우선합니다.

## 자원 조회·연결

전제: app 적용 완료.

| 조회 대상 | 조건 | 전달 대상 |
|---|---|---|
| VPC | `Name=arcamap-vpc` | 서브넷·보안 그룹 조회 범위 |
| DB 서브넷 | 위 VPC, 2a·2c, `Name=arcamap-database-<AZ>` | RDS 서브넷 그룹 |
| DB 보안 그룹 | 위 VPC, 이름 `arcamap-database` | RDS 네트워크 접근 |

```text
DB 로그 그룹 2개 → RDS·서브넷 그룹 → RDS 지표 경보
```

| 보호·접속 설정 | 값 |
|---|---|
| 네트워크 | 비공개 IPv4, TCP 5432, API 보안 그룹만 허용 |
| 가용성 | Multi-AZ |
| 스토리지 | 암호화 gp3, 자동 확장 상한 100 GiB |
| 백업·삭제 | 자동 백업 3일, 삭제 보호, 최종 스냅샷 생성 |
| 로그 | PostgreSQL·upgrade 내보내기, 30일 보존 |

## 적용 절차

```bash
cd /root/protomaps
terraform -chdir=terraform/env/db init -lockfile=readonly
terraform -chdir=terraform/env/db plan -out=db.tfplan
terraform -chdir=terraform/env/db apply db.tfplan
terraform -chdir=terraform/env/db output database

aws rds describe-db-instances \
  --region ap-northeast-2 --db-instance-identifier arcamap-postgres \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint,MultiAZ:MultiAZ,Public:PubliclyAccessible}'
```

정상 기준: `available`, 포트 5432, `MultiAZ=true`, `Public=false`.

## 로그·경보

| 대상 | 설정 |
|---|---|
| PostgreSQL 로그 | `/aws/rds/instance/arcamap-postgres/postgresql` |
| 업그레이드 로그 | `/aws/rds/instance/arcamap-postgres/upgrade` |
| CPU | 평균 80% 이상, 300초·3/3 |
| 여유 메모리 | 최솟값 512 MiB 미만, 300초·3/3 |
| 여유 저장 공간 | 최솟값 5 GiB 미만, 300초·1/1 |
| 연결 수 | `db_max_connections` 입력 시 평균 80% 이상, 60초·3/3 |
| 알림 동작 | 비활성화, 수신 대상 없음 |

`M/N`: 최근 N개 구간 중 M개 이상이 임계값을 위반하면 경보. 연결 수 입력은 DB의 `SHOW max_connections;` 결과를 사용합니다.

## 출력·접속

| 출력 | 필드 |
|---|---|
| `database` | `identifier`, `address`, `port`, `name` |
| `log_groups` | `rds_postgresql`, `rds_upgrade`의 그룹 이름 |

운영 API는 VPC 내부에서 RDS에 직접 연결합니다. WAS는 RDS 식별자 `arcamap-postgres`로 주소·포트·DB·사용자를 조회하며, 접속 환경을 Secrets Manager에 저장합니다. 작업자 접속 경로는 SSM→WAS→RDS, TLS 설정은 RDS CA를 사용하는 `verify-full`입니다.
