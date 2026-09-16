# WAS 배포

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| AMI | OS·애플리케이션을 포함한 EC2 시작 이미지 | API·의존성·systemd 서비스 사전 설치 |
| Image Builder | OS·소프트웨어 설치를 통한 AMI 생성 자동화 | API가 설치된 운영 이미지 생성 |
| 시작 템플릿 | EC2 생성에 사용할 AMI·인스턴스·권한·디스크 설정 | ASG가 최신 템플릿 버전 참조 |
| ASG | 인스턴스 수와 상태를 관리하는 그룹 | 최소 2대, 최대 4대 |
| Instance Refresh | 변경된 시작 템플릿으로 기존 인스턴스 교체 | Rolling 교체 |
| 인스턴스 프로파일 | IAM 역할을 EC2에 연결하는 객체 | 운영·이미지 빌드용 분리 |
| Secrets Manager | 비밀값 저장·조회 서비스 | DB 접속 환경을 서비스 시작 시 조회 |
| systemd | Linux 서비스 시작·종료·재시작 관리 | `arcamap-api.service` |

## 배포 흐름

```text
WAS 소스 5개 파일
  → was/.artifacts/was.tar.gz
  → S3의 was/<SHA-256>.tar.gz
  → Image Builder: OS·API·서비스 설치
  → AMI → 시작 템플릿 → ASG 교체 → ALB 상태 확인
```

## 현재 구성

| 항목 | 값 |
|---|---|
| 기반 OS | Canonical Ubuntu 26.04 · x86_64 · 서울 리전의 최신 일치 AMI 조회 |
| 이미지 레시피 버전 | `1.1.2` |
| 운영·빌드 인스턴스 | `t3.small` · gp3 20 GiB · 암호화 |
| Python / uv | `3.14.7` / `0.12.12` |
| FastAPI / Uvicorn / Psycopg | `0.141.1` / `0.52.4` / `3.3.5` |
| 실행 계정·위치 | `arcamap` · `/opt/arcamap/was` |
| API 수신 | HTTP `0.0.0.0:8080` |
| ALB 수신 | HTTP 80 → HTTPS 443 리다이렉트, HTTPS → WAS:8080 |
| 메타데이터 | IMDSv2 필수, hop limit 1 |
| EC2 상세 모니터링 | 비활성화 |

## IAM 권한

| 역할 | 프로파일 | 권한 |
|---|---|---|
| `arcamap-api-ec2` | `arcamap-api-instance-profile` | SSM, CloudWatch Agent, 지정 Secret의 `GetSecretValue` |
| `arcamap-imagebuilder-ec2` | `arcamap-imagebuilder-instance-profile` | 운영 역할의 공통 권한 + Image Builder, 지정 S3 배포 객체 읽기, 시스템 로그 조회 |

- 신뢰 주체: `ec2.amazonaws.com`
- 배포 객체: 현재 SHA-256 키 하나로 `s3:GetObject` 제한
- 시스템 로그 조회 권한: `/arcamap/ec2/system`의 `logs:FilterLogEvents`
- Secret: `arcamap/api/database` ARN 하나로 조회 제한

## DB 비밀값과 서비스 기동

| 위치 | 내용 | 수명 |
|---|---|---|
| Secrets Manager | `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `PGSSLROOTCERT` | 운영 접속 설정 |
| `/etc/arcamap/secret.env` | `AWS_REGION`, `ARCAMAP_SECRET_ID` | AMI에 포함 |
| `/etc/arcamap/rds-ap-northeast-2-bundle.pem` | RDS 서버 인증서 검증용 CA | AMI에 포함 |
| `/run/arcamap/runtime.env` | 시작 시 조회한 DB 접속 환경 | tmpfs, root:root·0600 |

```text
EC2 부팅
  → systemd의 arcamap-api 시작
  → ExecStartPre: Secrets Manager 조회
  → /run/arcamap/runtime.env 생성
  → arcamap 계정으로 Uvicorn 실행
```

- 빌드 단계: 서비스 설치·enable, API 실행과 DB 비밀값 저장 없음
- 운영 user_data: CloudWatch Agent 시작
- DB 연결: `sslmode=verify-full`, 연결·쿼리 제한 시간 각각 5초
- 서비스 재시작: 실패 후 5초, 시작 제한 60초
- `/etc/arcamap/runtime.env`, `/etc/arcamap/database.env`: 현재 서비스에서 미사용

## 상태 검사·교체

| 항목 | 설정 |
|---|---|
| ASG 고장 판단 | 실제 입력 `ELB` |
| 최소·최대 인스턴스 | 2·4 |
| CPU 목표 추적 | 평균 CPU 50%, 축소 활성화 |
| 상태 검사 유예·warmup | 각각 300초 |
| ALB 검사 | HTTP 8080 · `/health` · 200 |
| ALB 간격·제한 시간 | 30초·5초 |
| 정상·비정상 판정 | 연속 성공 5회·실패 2회 |
| 대상 해제 대기 | 300초 |
| Rolling 정상 비율 | 최소 0%·최대 100%, 일치 인스턴스 건너뛰기 |

- `ELB`: EC2 상태와 함께 로드 밸런서의 대상 상태를 고장 판단에 사용
- `/health`: API 응답 검사; DB 장애는 `/health/db`로 별도 확인
- 최소 정상 비율 0%: 교체 중 API 중단 가능

## 배포 절차

작업 위치: `/root/protomaps`  
전제: app·db 적용, 운영 RDS 비밀번호, API 인증서·DNS 역할 준비.

### 1. 배포 파일 생성

```bash
mkdir -p was/.artifacts
tar -czf was/.artifacts/was.tar.gz -C was \
  main.py database.py pyproject.toml uv.lock .python-version
tar -tzf was/.artifacts/was.tar.gz
sha256sum was/.artifacts/was.tar.gz
```

포함 대상: 위 5개 파일. `.env`·`.venv` 제외.

### 2. 이미지 입력 확정

| 입력 | 처리 |
|---|---|
| `image_builder_version` | 이미 발행한 구성요소·레시피 변경 시 새 버전 지정 |
| `db_password` | 기존 운영 RDS와 동일한 비밀번호 공급 |
| 운영 루트 볼륨 | 이미지 빌드 볼륨 이상 |

### 3. 계획·적용

```bash
read -r -s -p '운영 RDS 비밀번호: ' TF_VAR_db_password
export TF_VAR_db_password

terraform -chdir=terraform/env/was init -lockfile=readonly
terraform -chdir=terraform/env/was plan -out=was.tfplan
terraform -chdir=terraform/env/was apply was.tfplan

unset TF_VAR_db_password
terraform -chdir=terraform/env/was output built_image
terraform -chdir=terraform/env/was output launch_template
```

| 단계 | 성공 기준 |
|---|---|
| S3 | 아카이브 해시와 객체 키 일치 |
| 이미지 빌드 | 이미지 생성 완료, 서울 리전 AMI 출력 |
| 시작 템플릿 | 새 AMI 참조 |
| 비밀값 | 운영 RDS 연결에 사용할 접속 설정 저장 |

### 4. ASG·ALB 확인

```bash
aws autoscaling describe-instance-refreshes \
  --region ap-northeast-2 --auto-scaling-group-name arcamap-api
aws autoscaling describe-auto-scaling-groups \
  --region ap-northeast-2 --auto-scaling-group-names arcamap-api \
  --query 'AutoScalingGroups[].{Desired:DesiredCapacity,Instances:Instances}'

arcamap_target_group="$(terraform -chdir=terraform/env/was output -json alb | jq -r '.target_group_arn')"
aws elbv2 describe-target-health \
  --region ap-northeast-2 --target-group-arn "$arcamap_target_group"

curl -sS -i --max-time 15 https://api.arcamap.app/health
curl -sS -i --max-time 15 https://api.arcamap.app/health/db
```

판정: 교체 작업 성공, 목표 수의 인스턴스 `InService`, ALB 대상 `healthy`, 두 API HTTP 200.

## EC2 내부 점검

실행 위치: SSM으로 접속한 WAS EC2.

```bash
systemctl is-enabled arcamap-api
systemctl is-active arcamap-api
sudo stat -c '%U:%G:%a' /run/arcamap/runtime.env
findmnt -n -o FSTYPE -T /run/arcamap/runtime.env
curl -sS -i http://127.0.0.1:8080/health/db
sudo journalctl -u arcamap-api -n 50 --no-pager
```

| 항목 | 정상 기준 |
|---|---|
| 서비스 | `enabled`·`active` |
| 런타임 파일 | `root:root:600`, `tmpfs` |
| DB 점검 | HTTP 200, `database: ok` |
