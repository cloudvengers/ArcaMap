# RDS PostgreSQL

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| DB 서브넷 그룹 | RDS 배치 후보 서브넷 집합 | 서로 다른 AZ의 DB 서브넷 2개 |
| Multi-AZ | 다른 AZ의 대기 인스턴스로 장애 대응 | 읽기 분산용 복제본과 구분 |
| 스토리지 자동 확장 | 저장 공간 부족 시 설정 상한까지 용량 확장 | 20→최대 100 GiB |
| 최종 스냅샷 | DB 삭제 전 마지막 저장 상태 보존 | 삭제 보호 해제 후 삭제 시 생성 |
| Write-only 비밀번호 | state·plan에 저장하지 않는 비밀번호 입력 | `password_wo` |

## 현재 구성

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/database` / `terraform/env/db` |
| 식별자 / DB / 서브넷 그룹 | `arcamap-postgres` / `arcamap` / `arcamap-database` |
| 엔진 / 클래스 | PostgreSQL `17.11` / `db.t4g.medium` |
| 네트워크 | 비공개 IPv4, Multi-AZ, TCP 5432 |
| 접근 허용 | app의 DB 보안 그룹, API 그룹에서 5432 |
| 스토리지 | 암호화 gp3, 20 GiB, 자동 확장 상한 100 GiB |
| 버전 변경 | 자동 마이너 업그레이드·메이저 업그레이드 허용 모두 비활성화 |
| 백업 | 자동 백업 3일 |
| 삭제 | 삭제 보호 활성화, 최종 스냅샷 생성 |
| 로그 내보내기 | `postgresql`, `upgrade` |

## 입력

| 변수 | 공급 값·조건 |
|---|---|
| `database_subnet_ids` | db 루트가 조회한 2a·2c DB 서브넷 ID |
| `database_security_group_id` | 같은 VPC의 `arcamap-database` 그룹 ID |
| `db_engine_version` | `17.11`, 고정 버전 |
| `db_instance_class` | `db.t4g.medium` |
| `db_allocated_storage` | 20 GiB 이상 정수, 현재 20 |
| `db_max_allocated_storage` | 초기 용량보다 큰 정수, 현재 100 |
| `db_username` | `<DB_USERNAME>`, 영문자로 시작하는 1~16자 영숫자 |
| `db_password` | sensitive·ephemeral, 8~128자 ASCII, `/`·큰따옴표·`@`·앞뒤 공백 제외 |
| `db_final_snapshot_identifier` | `arcamap-postgres-final`, 삭제 시 기존 스냅샷과 이름 중복 불가 |

`password_wo_version=1`. 비밀번호 변경 시 입력값과 버전을 함께 갱신하고, WAS Secret에도 같은 비밀번호를 반영합니다.

## 적용·연결

```text
DB 로그 그룹 준비 → DB 서브넷 그룹·RDS 생성 → RDS 식별자를 경보에 연결
WAS → VPC 내부 → RDS:5432
```

```bash
cd /root/protomaps
terraform -chdir=terraform/env/db plan -out=db.tfplan
terraform -chdir=terraform/env/db apply db.tfplan
terraform -chdir=terraform/env/db output database

aws rds describe-db-instances \
  --region ap-northeast-2 --db-instance-identifier arcamap-postgres \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint,MultiAZ:MultiAZ,Public:PubliclyAccessible,Encrypted:StorageEncrypted,BackupDays:BackupRetentionPeriod,DeletionProtection:DeletionProtection}'
```

## 출력·정상 기준

| 항목 | 정상 기준 |
|---|---|
| `database.identifier` | `arcamap-postgres` |
| `database.address` | RDS 엔드포인트 |
| `database.port` / `database.name` | 5432 / `arcamap` |
| RDS 상태 | `available` |
| 보호 설정 | Multi-AZ·암호화·삭제 보호 true, Public false, 백업 3일 |
| API 접속 | RDS CA와 호스트 이름을 확인하는 `sslmode=verify-full` |

WAS는 RDS 이름으로 주소·포트·DB·사용자를 조회합니다. 접속 포트는 데이터 소스의 `port`를 사용합니다.
