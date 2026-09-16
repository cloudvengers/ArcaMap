# 운영 RDS·데이터 적재

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| Multi-AZ | 다른 AZ의 대기 인스턴스를 이용한 장애 대응 구성 | 운영 RDS, 읽기 분산용 복제본과 구분 |
| DB 서브넷 그룹 | RDS 배치에 사용할 서브넷 집합 | 2a·2c의 DB 서브넷 |
| TLS `verify-full` | 암호화와 서버 인증서·호스트 이름 검증 | RDS CA와 엔드포인트 사용 |
| 마이그레이션 | 버전별 DB 구조 변경 | `public.data_migrations`에 적용 이력 저장 |
| 트랜잭션 | 여러 SQL 작업의 일괄 확정·취소 단위 | 성공 시 COMMIT, 실패 시 ROLLBACK |
| 외래 키 | 다른 테이블의 행을 참조하는 제약 | 보존목록의 `place_id` → 장소 |
| Upsert | 키가 없으면 추가, 있으면 값 갱신 | CSV와 다른 필드만 갱신 |

## 현재 구성

| 항목 | 값 |
|---|---|
| RDS 식별자 / DB | `arcamap-postgres` / `arcamap` |
| 엔진 / 인스턴스 | PostgreSQL `17.11` / `db.t4g.medium` |
| 네트워크 | 프라이빗 IPv4 · TCP 5432 · Multi-AZ |
| 스토리지 | 암호화 gp3 20 GiB · 자동 확장 상한 100 GiB |
| 자동 백업 | 3일 |
| 삭제 보호 | 활성화 |
| 최종 스냅샷 | 삭제 시 생성 · 입력 이름 `arcamap-postgres-final` |
| 자동 마이너 업그레이드 | 비활성화 |
| 로그 내보내기 | PostgreSQL·upgrade |

## 인프라 적용

작업 위치: `/root/protomaps`  
전제: app 적용, `terraform/env/db/terraform.tfvars` 입력.

```bash
terraform -chdir=terraform/env/db init -lockfile=readonly
terraform -chdir=terraform/env/db plan -out=db.tfplan
terraform -chdir=terraform/env/db apply db.tfplan
terraform -chdir=terraform/env/db output database

aws rds describe-db-instances \
  --region ap-northeast-2 --db-instance-identifier arcamap-postgres \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint,MultiAZ:MultiAZ,Public:PubliclyAccessible}'
```

판정: `available`, 포트 5432, `MultiAZ: true`, `Public: false`.

## 접속 경로

| 주체 | 경로 | 인증 |
|---|---|---|
| 운영 API | WAS → VPC 내부 → RDS:5432 | 서비스 시작 시 Secrets Manager 조회 |
| 작업자 | PC:15432 → SSM → WAS EC2 → RDS:5432 | SSM 실행 권한 + DB 계정 |

SSM 터널: 작업자의 DB 관리 경로. API의 DB 요청은 같은 VPC에서 직접 연결.

### 1. SSM 터널

필요 도구: AWS CLI, Session Manager plugin, Terraform, jq, PostgreSQL 클라이언트.

터미널 A · 작업 위치 `/root/protomaps`:

```bash
arcamap_db_host="$(terraform -chdir=terraform/env/db output -json database | jq -r '.address')"
arcamap_instance_id="$(aws autoscaling describe-auto-scaling-groups \
  --region ap-northeast-2 --auto-scaling-group-names arcamap-api \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId | [0]' \
  --output text)"

aws ssm start-session \
  --region ap-northeast-2 --target "$arcamap_instance_id" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$arcamap_db_host,portNumber=5432,localPortNumber=15432"
```

판정: 포트 15432 열림, 세션 유지. 대상 EC2의 SSM 등록·RDS 이름 해석·5432 통신 필요.

### 2. SQL 접속

터미널 B · 작업 위치 `/root/protomaps`:

```bash
arcamap_db_host="$(terraform -chdir=terraform/env/db output -json database | jq -r '.address')"
read -r -s -p '운영 RDS 비밀번호: ' PGPASSWORD
export PGPASSWORD
export PGHOSTADDR=127.0.0.1

bash data/psql.sh --host="$arcamap_db_host" --port=15432 \
  -c 'SELECT current_database(), current_user, inet_server_addr(), inet_server_port();' \
  -c 'SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();'
```

| 설정 | 역할 |
|---|---|
| `--host` | 실제 운영 RDS 이름, TLS 호스트 검증 |
| `PGHOSTADDR` | 실제 연결할 IP, 로컬 터널 주소 |
| `--port=15432` | 터널의 로컬 포트 |
| `psql.sh` | RDS CA·verify-full·오류 시 중단·UTF-8 적용 |

- 운영 작업에서는 `--host`·`--port` 명시
- 정상 기준: DB `arcamap`, 서버 포트 5432, `ssl = true`

## 적재 절차

실행 위치: 터미널 B. SSM 터널과 위 접속 환경 유지.

### 1. 적재 대상

| 테이블 | 내용 | 기준 |
|---|---|---|
| `public.places` | 저장소·보존 시설, 13개 필드 | 50건, 좌표 보유 45건 |
| `public.place_collections` | 시설에 속한 보존목록, 8개 필드 | 9건, `place_id`로 장소 참조 |
| `public.data_migrations` | 스키마 적용 버전·시각 | `001_places`, `002_collections` |

### 2. 스키마·데이터 적용

```bash
bash data/psql.sh --host="$arcamap_db_host" --port=15432 \
  -f migrations/001_places.sql
bash data/psql.sh --host="$arcamap_db_host" --port=15432 \
  -f load_collections.sql
```

| 파일 | 동작 | 트랜잭션 |
|---|---|---|
| `001_places.sql` | 장소 테이블·제약·적용 이력 생성 | 독립 트랜잭션 |
| `load_collections.sql` | 보존목록 구조·외래 키 생성, 두 CSV 적재 | 구조·데이터를 한 트랜잭션으로 처리 |

- 적용된 마이그레이션 버전: 재생성 생략
- 같은 ID·같은 값: 갱신 생략
- 삭제 대상: 보존목록으로 이동한 `no_github_arctic_code_vault`, `ch_global_knowledge_vault`, `us_usda_national_animal_germplasm_program`만 처리
- 그 밖의 CSV 외 행: 자동 삭제 없음
- 실패 시: 해당 파일의 트랜잭션 롤백. 이미 완료한 `001_places`는 유지

### 3. 적재 결과 확인

```bash
bash data/psql.sh --host="$arcamap_db_host" --port=15432 <<'SQL'
SELECT (SELECT count(*) FROM public.places) AS places,
       (SELECT count(*) FROM public.place_collections) AS collections;
SELECT count(*) AS orphan_collections
FROM public.place_collections c LEFT JOIN public.places p USING (place_id)
WHERE p.place_id IS NULL;
SELECT version, applied_at FROM public.data_migrations ORDER BY version;
SQL
```

| 항목 | 정상 기준 |
|---|---|
| 장소 | 50건 |
| 보존목록 | 9건 |
| 부모 없는 보존목록 | `orphan_collections = 0` |
| 적용 버전 | `001_places`, `002_collections` |

### 4. 연결 종료

```bash
unset PGPASSWORD PGHOSTADDR
```

터미널 A: `Ctrl+C`로 SSM 세션 종료.

## 적용 기록

| 시점 | 결과 |
|---|---|
| 2026-09-15 01:31:24 KST | 기존 EC2의 SSM 실행 환경에서 운영 RDS 반영 |
| 적재 | 장소 50건·보존목록 9건, 이전 행 삭제 0건 |
