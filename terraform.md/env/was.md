# WAS 인프라 적용

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| AMI | OS·애플리케이션을 포함한 EC2 시작 이미지 | API·의존성·systemd 서비스 사전 설치 |
| 시작 템플릿 | EC2 생성에 사용할 이미지·디스크·권한 설정 | 새 AMI를 ASG에 전달 |
| ASG | 인스턴스 수와 상태를 관리하는 그룹 | 최소 2대·최대 4대, CPU 목표 50% |
| 인스턴스 프로파일 | IAM 역할을 EC2에 연결하는 객체 | 운영·이미지 빌드용 분리 |
| Secret | 암호화하여 보관하는 비밀값 | 서비스 시작 시 DB 접속 환경 조회 |
| DNS 별칭 | AWS 자원으로 연결하는 Route 53 레코드 | API 도메인 → ALB |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 실행 위치 | `/root/protomaps/terraform/env/was` |
| Terraform / AWS Provider | `1.16.1` / `6.63.0` |
| 리전 / State | `ap-northeast-2` / 루트의 `terraform.tfstate` |
| `api_domain_name` / `frontend_domain_name` | `api.arcamap.app` / `arcamap.app` |
| `asg_cpu_target` / `asg_max_size` | 50% / 4대 |
| `asg_health_check_type` | 입력 `ELB`, 변수 기본값 `EC2` |
| `ec2_instance_type` / `ec2_root_volume_size` | `t3.small` / 20 GiB |
| `image_builder_instance_type` / `image_builder_root_volume_size` | `t3.small` / 20 GiB |
| `image_builder_version` | `1.1.2` |
| `cloudwatch_agent_version` | `1.300072.0b1766` |
| `log_retention_days` | 30일 |
| `db_password` | 기존 운영 RDS 비밀번호, sensitive·ephemeral |
| `route53_role_arn` | `arn:aws:iam::438465145630:role/Route53` |
| `route53_zone_id` | `Z05495112R0T3ZW9NIKIZ` |

운영 루트 볼륨은 빌드 볼륨 이상. 두 도메인과 두 인스턴스 프로파일 이름은 각각 서로 달라야 합니다.

## 기존 자원 조회

전제: app·db 적용 완료, API 인증서 `ISSUED`.

| 대상 | 조회 조건 | 전달 대상 |
|---|---|---|
| VPC | `Name=arcamap-vpc` | 서브넷·보안 그룹 조회 범위 |
| 퍼블릭 서브넷 | 위 VPC, 2a·2c, `Name=arcamap-public-<AZ>` | ALB |
| API 서브넷 | 위 VPC, 2a·2c, `Name=arcamap-api-<AZ>` | ASG, Image Builder는 2a |
| 보안 그룹 | 위 VPC, `arcamap-alb`·`arcamap-api` | ALB·EC2 |
| RDS | 식별자 `arcamap-postgres` | Secret의 주소·포트·DB·사용자 |
| API 인증서 | 서울 리전, `api.arcamap.app`, `ISSUED` | HTTPS 리스너 |
| 기반 AMI | Canonical Ubuntu 26.04, x86_64, 최신 일치 이미지 | Image Builder 레시피 |

RDS 접속 포트는 `data.aws_db_instance.postgres.port` 사용. `db_instance_port`는 사용하지 않습니다.

## IAM·배포 자원

| 대상 | 구성 |
|---|---|
| 운영 역할 / 프로파일 | `arcamap-api-ec2` / `arcamap-api-instance-profile` |
| 빌드 역할 / 프로파일 | `arcamap-imagebuilder-ec2` / `arcamap-imagebuilder-instance-profile` |
| 공통 권한 | SSM·CloudWatch Agent·지정 Secret 조회 |
| 빌드 추가 권한 | Image Builder·지정 S3 배포 객체 읽기·시스템 로그 조회 |
| 역할 신뢰 주체 | `ec2.amazonaws.com` |
| 배포 버킷 | `arcamap-deploy-` 접두사, 비공개·암호화·TLS 필수 |
| 배포 객체 | `was/<아카이브 SHA-256>.tar.gz` |
| Secret | `arcamap/api/database`, `secret_string_wo_version=1` |

Secret 필드: `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `PGSSLROOTCERT`.

```text
소스 5개 파일 → 배포 S3 → Image Builder → API 포함 AMI → 시작 템플릿 → ASG
EC2 부팅 → systemd → Secret 조회 → /run/arcamap/runtime.env → API 시작
```

비밀번호는 AMI에 저장하지 않습니다. 런타임 파일은 tmpfs의 `root:root:600`, DB 연결은 RDS CA를 사용하는 `verify-full`입니다.

## 적용 절차

### 1. 배포 아카이브 생성

```bash
cd /root/protomaps
mkdir -p was/.artifacts
tar -czf was/.artifacts/was.tar.gz -C was \
  main.py database.py pyproject.toml uv.lock .python-version
sha256sum was/.artifacts/was.tar.gz
```

구성요소·레시피 변경 시 `image_builder_version`에 새 버전 지정. 아카이브에 `.env`·`.venv`를 포함하지 않습니다.

### 2. 계획·적용

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

동일 변수가 `terraform.tfvars`에도 있으면 파일 값이 우선합니다. DB 비밀번호 변경 시 RDS와 Secret의 값·write-only 버전을 함께 관리합니다.

### 3. 운영 상태 확인

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

| 항목 | 정상 기준 |
|---|---|
| 이미지·시작 템플릿 | 서울 리전의 새 AMI 연결 |
| ASG | 교체 성공, 목표 수의 인스턴스 `InService` |
| ALB | 대상 `healthy`, `/health` HTTP 200 |
| DB 접속 | `/health/db` HTTP 200 |

## DNS·로그·출력

| 대상 | 설정 |
|---|---|
| API DNS | `aws.dns`로 DNS 계정 역할 사용, `api.arcamap.app` A 별칭 → ALB |
| 별칭 옵션 | `evaluate_target_health=true`, `allow_overwrite=false` |
| 시스템·API 로그 그룹 | `/arcamap/ec2/system`, `/arcamap/api/application` |
| ALB·이미지 로그 그룹 | `/aws/vendedlogs/elb/arcamap-api`, `/aws/imagebuilder/arcamap-api` |
| API 로그 수집 | systemd journal 사용, API 전용 그룹의 별도 파일 수집 설정 없음 |
| 경보 | WAS 6개, 알림 동작 비활성화 |
| 출력 | `alb`, `api_url`, `autoscaling_group`, `launch_template`, `log_groups`, `built_image` |

ASG는 `ELB` 상태 검사와 300초 유예를 사용합니다. Rolling 교체의 정상 비율은 최소 0%·최대 100%로, 교체 중 API 중단이 가능합니다.
