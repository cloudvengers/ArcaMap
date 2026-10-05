# RDS 의존성 전환 — 데이터 내용을 보존하고 DSQL 기준으로 신규 구성

## 배경과 문제

### 배경

- 현재 AWS에 서비스 인프라는 배포되어 있지 않으며, 고가용성 구성을 성능 효율성·지속 가능성·비용 최적화·보안을 고려한 단일 구성 운영 기반으로 변경합니다.
- 데이터베이스는 서울 리전의 Aurora DSQL로 전환합니다. API EC2는 프라이빗 서브넷에서 ASG 최소 1대·최대 2대로 운영하며, 같은 운영 가용 영역의 API 서브넷에 DSQL 연결용 Interface VPC Endpoint를 배치합니다. 외부 통신에는 NAT Gateway 1개를 사용합니다.
- 기존 데이터의 내용과 의미를 보존하면서 스키마·접속·조회·적재 구성을 DSQL 기준으로 전환합니다.
- RDS 의존성은 DB 리소스뿐 아니라 접속정보, 보안그룹, IAM, 애플리케이션 SQL, 데이터 적재, Image Builder 검사, 모니터링, 백업에 연결되어 있습니다. 이 문서는 DSQL의 데이터·접속·배포·복구 구성을 정하며, 모니터링 정책은 CloudWatch 서비스 범위에서 정합니다.

### 문제

| 현재 코드의 의존성 | 확인한 구성과 전환이 필요한 이유 |
| --- | --- |
| `env/database`, `modules/database` | RDS 인스턴스·DB 서브넷 그룹과 인스턴스 유형·엔진 버전·스토리지·비밀번호·스냅샷 설정을 사용합니다. DSQL 클러스터의 관리 항목으로 전환해야 합니다. |
| `modules/network`, `modules/security`, `env/network` | RDS용 DB 서브넷 2개, 격리 라우팅 테이블, DB 보안그룹, API → DB TCP 5432 규칙이 있습니다. DSQL 연결 Endpoint를 대상으로 바꿔야 합니다. |
| `env/api/data.tf`, `deployment.tf`, `iam.tf` | `arcamap-postgres` RDS 조회 결과와 고정 비밀번호를 Secrets Manager에 저장하고, 운영·빌드 EC2가 Secret을 읽습니다. DSQL 클러스터 정보와 IAM 인증으로 바꿔야 합니다. |
| `app/was/database.py`, 배포 서비스·환경 예제 | `PGDATABASE=arcamap`, 고정 `PGPASSWORD`, RDS CA 파일을 전제로 요청마다 연결합니다. DSQL의 DB 이름·인증·TLS 신뢰 체계와 다릅니다. |
| `app/data/*.sql`, `migrations/001_places.sql`, `psql.sh` | `text[]`, 임시 테이블, `DO` 블록, `LOCK TABLE`, DDL·DML 혼합 트랜잭션과 고정 RDS 주소를 사용합니다. DSQL 호환성에 맞춘 저장·적재·접속 방식이 필요합니다. |
| `env/api/image-builder.tf`, `modules/image-builder` | RDS CA를 AMI에 설치하고, Secret을 읽어 `/health/db`에서 `SELECT 1`을 검사합니다. 연결 대상과 인증 경로를 함께 전환해야 합니다. |
| DB 복구 설정·설명 | RDS 자동 백업 3일, 삭제 보호, 삭제 전 최종 스냅샷을 전제로 합니다. DSQL의 백업·복구 방식에 맞춰 보호 기능을 이어가야 합니다. |

- DSQL은 클러스터당 기본 DB `postgres`를 사용합니다. DDL과 DML은 별도 트랜잭션으로 실행하며, 한 트랜잭션에 DDL은 1개만 포함할 수 있습니다. 임시 테이블과 PL/pgSQL 의존성도 전환해야 합니다. [AWS PostgreSQL 전환 지침](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-postgresql-compatibility-migration-guide.html)
- DSQL은 배열 컬럼을 지원하지 않지만 조회 중 배열 연산은 지원합니다. `numeric`의 기본값은 `numeric(18,6)`이므로 원본 좌표의 소수 정밀도를 보존하려면 정밀도와 소수 자릿수를 명시해야 합니다. [AWS 지원 자료형](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-postgresql-compatibility-supported-data-types.html)
- DSQL은 외래키를 지원합니다. 장소와 컬렉션 사이의 관계를 키와 외래키로 구성합니다. [AWS 외래키 지원](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-foreign-key-constraints.html)

## 검토한 대안

### 접속·인증 방식

| 대안 | 인증 처리 | 구현·관리 부담 |
| --- | --- | --- |
| 기존 psycopg에 IAM 토큰 생성·갱신 직접 구현 | 새 연결에 사용할 토큰을 직접 생성 | 토큰 수명·AWS 자격증명·새 연결의 인증을 직접 관리 |
| 공식 DSQL Python Connector와 psycopg 사용 | Connector가 연결 시 IAM 토큰 생성 | Connector 의존성을 추가하며 기존 드라이버와 파라미터 바인딩 사용 |

### 목록 저장 형식

| 대안 | 저장·조회 방식 | 변환·검증 부담 |
| --- | --- | --- |
| 세미콜론 구분 `text` | CSV 표현을 재사용하고 조회 시 문자열을 배열로 변환 | 구분자 형식과 문자열 변환 관리 |
| JSONB 배열 | 목록을 자료형으로 표현하고 JSON 연산으로 조회 | 원본 CSV를 JSONB 배열로 변환하고 목록·요소 검증 |

## 결정과 이유

**선택: 데이터 내용과 의미를 보존하고, 공식 DSQL Connector·IAM 인증·JSONB 기반 데이터 모델과 운영 구성을 새로 생성**

- 공식 Connector로 IAM 토큰 생성 부담을 줄이고, JSONB로 목록을 표현해 조회 시 구분자 처리와 문자열의 배열 변환을 줄입니다.
- **보존 기준:** 기존 데이터의 값·원본 ID·NULL 의미·목록 순서·좌표 정밀도·장소와 컬렉션의 연결 관계를 보존합니다. 내부 키와 테이블 구조는 DSQL에 맞춰 설계하고 원본 ID와의 대응 관계를 유지합니다.
- DB·적재·API의 데이터 표현을 새 모델에 맞춰 정의하며, 서비스의 표시·검색·필터 결과가 같은 정보를 제공하도록 연결합니다.
- DSQL에 필요한 접속·보안·배포·복구 기능을 포함해, 제거되는 RDS를 참조하는 설정이 남지 않도록 합니다.
- **원본 규모:** 장소 50건·컬렉션 9건을 새 모델로 변환해 초기화합니다. 보존 단위는 원본 레코드의 내용과 관계이며, 물리적 테이블 수와 행 구성은 새 모델에 맞춰 정합니다.

### DB 리소스와 네트워크

- DB 관리 영역에 단일 리전 DSQL 클러스터와 연결 Endpoint를 생성합니다. 공통 백업 금고·백업 및 복원 IAM 권한은 `env/backup`에서 관리합니다.
- RDS 인스턴스·DB 서브넷 그룹과 인스턴스 유형·엔진 버전·gp3 용량·마스터 비밀번호·RDS 백업 설정은 제거합니다.
- 클러스터 삭제 보호를 활성화합니다. DB 출력은 클러스터 ID·ARN·리전·포트 5432·DB 이름 `postgres`·PrivateLink 접속 호스트로 바꾸고, API 루트가 해당 정보를 입력받도록 합니다.
- RDS 전용 DB 서브넷·라우팅 테이블·연결·출력을 제거합니다. API와 Image Builder가 사용하는 운영 가용 영역의 프라이빗 서브넷에 연결용 Interface Endpoint를 배치하고 Private DNS를 활성화합니다.
- Endpoint 서비스명은 대상 클러스터의 `GetVpcEndpointServiceName` 결과를 사용합니다. 접속 호스트는 `<cluster-id>.<service-identifier>.ap-northeast-2.on.aws` 형식으로 구성하고, 접속과 토큰 생성에 같은 호스트를 사용합니다. [AWS PrivateLink 연결 지침](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/privatelink-managing-clusters.html)
- RDS DB 보안그룹을 제거하고 DSQL Endpoint용 보안그룹을 구성합니다. 운영 API와 Image Builder 전용 보안그룹에서 Endpoint로 TCP 5432 통신을 허용하고, Endpoint 인바운드는 두 보안그룹으로 제한합니다.
- Image Builder 전용 보안그룹은 운영 API와 분리하며 인바운드 규칙을 두지 않습니다. 아웃바운드는 외부 의존성·AWS 서비스 접근용 TCP 443과 DSQL Endpoint 보안그룹 대상 TCP 5432를 허용합니다.
- 연결용 Endpoint를 구성하며, 클러스터 관리용 Endpoint를 추가하지 않습니다. 클러스터 관리는 기존 AWS 관리 API 경로를 사용하고, DB 데이터 통신은 PrivateLink를 사용합니다.

### 접속정보·IAM·TLS

- API와 Image Builder의 IAM 역할에 대상 클러스터 ARN으로 제한한 `dsql:DbConnect`를 부여합니다. 각각의 읽기 전용 DB 역할을 생성하고 `AWS IAM GRANT`로 연결하며, 필요한 스키마 사용·테이블 조회 권한을 부여합니다.
- 초기 스키마·역할 설정은 별도의 운영자 IAM 주체에 부여한 `dsql:DbConnectAdmin`으로 수행합니다. 일상적인 데이터 적재·수정에는 별도의 쓰기 DB 역할과 `dsql:DbConnect`를 사용합니다. [AWS IAM·DB 역할 설정](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/using-database-and-iam-roles.html)
- 고정 DB 비밀번호, DB 접속정보용 Secrets Manager Secret·버전, 해당 Secret 읽기 정책, `db_password` 입력과 부팅 시 Secret 로더를 제거합니다. 접속 호스트·리전·포트·DB 이름·DB 역할·CA 경로는 systemd 환경 파일로 전달합니다.
- DB 접속 계층은 `aurora-dsql-python-connector`와 psycopg를 사용하는 DSQL 전용 코드로 새로 작성합니다. 새 연결의 IAM 토큰은 Connector가 EC2 IAM 역할의 자격증명으로 생성하며, 토큰을 AMI·환경 파일·Secret·로그에 저장하지 않습니다. [AWS Python Connector](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/SECTION_program-with-dsql-connector-for-python.html)
- `sslmode=verify-full`을 유지하고 RDS CA 대신 Amazon Root CA 1을 포함한 신뢰 저장소를 사용합니다. AMI에는 해당 CA 신뢰 구성을 포함합니다. [AWS TLS 인증서 지침](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/configure-root-certificates.html)
- `app/was/.env.example`, 배포 환경 예제, `app/data/psql.sh`의 접속 기준을 DSQL로 바꿉니다. psql은 접속 직전에 해당 DB 역할의 IAM 토큰을 생성해 사용하고, 운영자는 SSM으로 프라이빗 접속 경로를 확보합니다.

### DSQL 전용 애플리케이션·스키마·데이터 적재

- 접속·조회 계층은 공식 Connector와 연결 풀을 사용하며, 풀의 연결 수명은 DSQL 연결 한도인 60분 미만으로 설정합니다. [AWS Connector와 연결 풀](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/SECTION_program-with-dsql-connector-for-python.html)
- 쿼리에 파라미터 바인딩과 입력 검증을 적용합니다. DB 오류 시 HTTP 503을 반환하고 인증정보를 노출하지 않습니다.
- `preservation_type`은 원본 CSV의 구분 문자열을 목록으로 변환해 JSONB 배열로 저장합니다. DSQL은 JSONB와 PostgreSQL JSON 함수·연산자를 지원합니다. [AWS JSONB 지원](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-postgresql-compatibility-supported-data-types.html)
- 목록 포함 여부와 필터 선택지 조회는 JSONB 연산 기준으로 새로 작성합니다. 목록 형태·요소의 자료형·빈 값에 대한 검증을 새 데이터 모델의 제약과 적재 검증에 반영합니다.
- 테이블·컬럼·자료형·키·인덱스·제약조건은 보존 기준을 충족하도록 DSQL에 맞춰 설계합니다.
- DSQL 전용 스키마 생성·초기화 절차를 새로 작성합니다. DDL은 1개씩 별도 트랜잭션으로 실행하고, 인덱스는 `CREATE INDEX ASYNC`로 생성한 뒤 완료 상태를 확인합니다.
- 적재 코드는 Python `csv`와 공식 Connector의 파라미터 바인딩을 사용합니다. 원본을 검증·변환한 뒤 참조 관계 순서에 맞춰 적재하며, 같은 입력으로 반복 실행해도 결과가 같도록 구성합니다.
- DDL과 적재 이력 기록을 분리하고 DML 트랜잭션은 DSQL의 3,000행 변경 한도 안에서 실행합니다. [AWS 마이그레이션·트랜잭션 지침](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-postgresql-compatibility-migration-guide.html)
- 데이터 수정과 무결성 검사는 새 모델을 기준으로 구성합니다. 직렬화 충돌은 트랜잭션 전체를 제한된 횟수로 재시도하며, 실패하면 작업을 중단합니다. 외래키가 있는 쓰기는 추가 읽기와 충돌 처리가 필요합니다. [AWS 외래키 동작과 재시도](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-foreign-key-constraints.html)

### AMI 빌드와 배포 의존성

- AMI 구성에서 RDS CA·Secret ARN·Secret 로더를 제거하고 DSQL Connector, 접속 환경 파일, Amazon Root CA 신뢰 구성을 포함합니다.
- 기존 `/health`와 `/health/db` 검사 목적을 유지합니다. DB 검사는 Image Builder의 IAM 역할·읽기 전용 DB 역할로 DSQL에 접속해 `SELECT 1`을 실행하도록 바꾸고, RDS 이름과 Secret 파일을 전제로 한 검사도 수정합니다.
- 선행 조건은 클러스터·Endpoint 준비 → 운영·빌드 IAM 역할 준비 → DB 역할 매핑·스키마·데이터 초기화 → Image Builder DB 연결 검사 → AMI 기반 API 배포 순서로 구성합니다.
- 기존 ASG Instance Refresh와 장애 자동 복구 설정은 이어서 사용합니다. DB 관련 검사는 DSQL 접속·새 스키마 정합성·원본 데이터 내용 보존을 기준으로 구성합니다.

### 데이터 복구

- 운영자가 변경·삭제 전에 AWS Backup의 DSQL 전체 클러스터 온디맨드 백업을 실행하고 `Lifecycle.DeleteAfterDays=7`을 지정합니다. 보존기간은 복구 지점 생성 시점부터 7일입니다. [AWS DSQL 백업](https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-aurora.html)
- 새 백업 완료 후 변경을 진행하며, 삭제할 때는 백업 완료 후 클러스터 삭제 보호를 해제합니다. 백업에 실패하면 변경·삭제를 중단하고 기존 복구 지점을 유지합니다.
- 새 백업 완료 후 같은 대상의 기존 복구 지점을 운영자가 삭제해 최신 1개를 유지합니다. 정기·연속 백업 계획과 백업 실행·삭제 자동화는 구성하지 않습니다.
- `env/backup`에서 공통 금고·암호화 설정·백업 및 복원 IAM 권한을 관리하고 Aurora DSQL 보호를 활성화합니다. DB 영역은 원본 클러스터·삭제 보호·식별 정보와 복구 후 연결 설정을 관리합니다.
- 복구는 AWS Backup 복구 지점으로 새 DSQL 클러스터를 생성하는 방식입니다. 복구 후 클러스터 ARN을 참조하는 IAM 정책, Endpoint 서비스명·접속 호스트, DB 역할 매핑, API 배포 설정을 새 클러스터 기준으로 연결합니다. [AWS DSQL 복구](https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-auroradsql.html)
- README·모듈 설명·아키텍처의 RDS 접속·배포·복구 설명도 위 구성에 맞춰 변경합니다.

### 결과

- 이점: RDS 인스턴스와 그 운영 설정에 대한 의존성을 제거하고, DSQL 연결부터 데이터 조회·배포·복구까지 일관된 운영 기반을 마련합니다.
- 이점: 고정 DB 비밀번호 관리와 Secret 조회를 제거하고, 클러스터별 IAM 권한·읽기 전용 DB 역할·PrivateLink·TLS 검증으로 접속을 제한합니다.
- 이점: JSONB 목록과 공식 Connector를 사용해 문자열 변환과 인증 구현 부담을 줄입니다.
- 제약: 새 스키마·접속·조회·적재 코드와 데이터 대응 관계를 구성해야 합니다. 표현 방식이 바뀌는 API와 이를 사용하는 부분도 새 모델에 맞춰 연결해야 합니다.
- 제약: DSQL의 클러스터당 새 연결 생성률 기본 한도는 초당 100개이며 연결 수 쿼터도 있습니다. 연결 풀의 크기와 재사용 정책은 이 한도와 운영 부하를 고려해 정해야 합니다. [AWS 연결 한도](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/CHAP_quotas.html)
- 제약: IAM 역할·DB 역할 매핑·초기 데이터가 Image Builder 검사보다 먼저 준비되어야 합니다. 클러스터 복구 시에도 새 식별자로 연결 구성을 갱신해야 합니다.
- 제약: DSQL 처리량·저장량, Interface Endpoint, AWS Backup 전체 백업의 비용을 부담합니다. 백업 실행·완료 확인·기존 복구 지점 삭제는 운영자가 수행해야 합니다.
- 제약: 복구 지점 이후 변경은 해당 백업에 포함되지 않습니다. 변경이 없으면 새 백업을 만들지 않으며, 남은 복구 지점도 생성 후 7일이 지나면 만료되어 백업이 없을 수 있습니다.
- 제약: 복구에는 새 클러스터 생성과 접속 설정 갱신 시간이 필요합니다. 허용 가능한 데이터 유실 시간인 복구 목표 시점(RPO)과 허용 가능한 서비스 중단 시간인 복구 목표 시간(RTO)을 정하고, 복구 시험으로 목표 충족 여부를 확인합니다. [AWS 복구 목표 설명](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-of-on-premises-applications-to-aws/recovery-objectives.html)
