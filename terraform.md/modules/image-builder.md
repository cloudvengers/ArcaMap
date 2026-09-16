# 운영 AMI 생성

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 기반 AMI | 소프트웨어 설치를 시작할 OS 이미지 | Canonical Ubuntu 26.04 |
| 구성요소 | 이미지에 적용할 설치 작업 | CloudWatch Agent·FastAPI 설치 |
| 이미지 레시피 | 기반 AMI·구성요소·디스크를 묶은 정의 | `arcamap-api`, 버전 `1.1.2` |
| 빌드 인프라 | 이미지 생성에 사용할 EC2·서브넷·권한 | API 서브넷 2a의 `t3.small` |
| 아카이브 해시 | 배포 파일의 내용 식별값 | S3 객체 키·다운로드 무결성 확인 |
| IMDSv2 | 토큰을 요구하는 EC2 메타데이터 접근 방식 | 토큰 필수, hop limit 1 |

## 현재 구성

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/image-builder` / `terraform/env/was` |
| 리전 | WAS Provider의 `ap-northeast-2` |
| 기반 AMI 발행자 | Canonical `099720109477` |
| AMI 이름 필터 | `ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*` |
| AMI 선택 | `x86_64`, `available`, `most_recent=true` |
| 레시피·구성요소 버전 | `1.1.2` |
| 빌드 EC2 | `t3.small`, API 2a 서브넷·API 보안 그룹 |
| 루트 디스크 | 암호화 gp3 20 GiB, 종료 시 삭제 |
| 빌드 프로파일 | `arcamap-imagebuilder-instance-profile` |
| 실패 시 인스턴스 | 종료 |
| 이미지 생성 제한 시간 | 120분 |
| Python / uv | `3.14.7` / `0.12.12` |
| CloudWatch Agent | `1.300072.0b1766` |

기반 AMI는 Terraform 실행 시 조회합니다. 발행된 구성요소·레시피를 변경할 때는 `image_builder_version`에 새 버전을 지정합니다.

## 입력·연결

| 입력 | 공급 값·역할 |
|---|---|
| `api_subnet_id` / `api_security_group_id` | app이 만든 API 2a 서브넷·API 보안 그룹 |
| `image_builder_instance_profile_name` | WAS에서 생성한 빌드 프로파일 |
| `image_builder_instance_type` / `image_builder_root_volume_size` | `t3.small` / 20 GiB |
| `image_builder_version` | 구성요소·레시피 버전 |
| `cloudwatch_agent_version` | 설치할 고정 Agent 버전 |
| `cloudwatch_agent_config_json` | journald 수집 설정 |
| `cloudwatch_agent_start` | Agent 설정 파일을 읽어 시작하는 명령 |
| `system_log_group_name` | `/arcamap/ec2/system` |
| `imagebuilder_log_group_name` | `/aws/imagebuilder/arcamap-api` |
| `api_installation` | 아카이브·서비스·Secret 연결 객체 |

| `api_installation` 필드 | 내용 |
|---|---|
| `artifact_uri` | `s3://<배포 버킷>/was/<SHA-256>.tar.gz` |
| `artifact_sha256` | 아카이브 SHA-256 |
| `service_base64` | `arcamap-api.service` 내용 |
| `secret_loader_base64` | `load-runtime-env.sh` 내용 |
| `rds_ca_base64` | RDS 서울 리전 CA 번들 |
| `secret_arn` | `arcamap/api/database` Secret ARN |

선행 조건: 같은 AZ의 NAT·외부 HTTPS 경로, 로그 그룹, 배포 객체, IAM 정책 연결. 빌드 역할은 SSM·CloudWatch·Image Builder·지정 Secret 조회·지정 S3 객체 읽기 권한을 사용합니다.

## 설치 흐름

```text
기반 Ubuntu AMI
  → CloudWatch Agent 설치·설정
  → AWS CLI 설치·S3 아카이브 다운로드
  → 아카이브 SHA-256 확인·압축 해제
  → Python·uv·잠금 파일의 운영 의존성 설치
  → RDS CA·Secret 로더·systemd 서비스 설치
  → 서비스 enable → 운영 AMI 생성
```

| 위치 | 내용 |
|---|---|
| `/opt/arcamap/was` | API 소스·가상환경 |
| `/opt/arcamap/python` | Python 런타임 |
| `/etc/systemd/system/arcamap-api.service` | `arcamap` 계정으로 API 실행 |
| `/usr/local/libexec/arcamap-load-environment` | 서비스 시작 전 Secret 조회 |
| `/etc/arcamap/secret.env` | 리전·Secret ARN |
| `/etc/arcamap/rds-ap-northeast-2-bundle.pem` | RDS CA |
| `/opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json` | Agent 원본 설정 |

빌드 단계에서는 API 서비스 설치·enable만 수행합니다. DB 비밀번호는 AMI에 저장하지 않으며, 운영 서비스 시작 시 `/run/arcamap/runtime.env`에 불러옵니다.

## 생성 절차

실행 위치: `/root/protomaps`. WAS 입력의 기존 운영 DB 비밀번호와 이미지 버전 준비.

```bash
mkdir -p was/.artifacts
tar -czf was/.artifacts/was.tar.gz -C was \
  main.py database.py pyproject.toml uv.lock .python-version
sha256sum was/.artifacts/was.tar.gz

terraform -chdir=terraform/env/was plan -out=was.tfplan
terraform -chdir=terraform/env/was apply was.tfplan
terraform -chdir=terraform/env/was output built_image
```

## 출력·정상 기준

| `image` 출력 | 내용 | 정상 기준 |
|---|---|---|
| `id` | Provider 리전과 일치하는 빌드 AMI | 서울 리전의 생성 완료 AMI |
| `root_device_name` | 기반 AMI의 루트 장치 이름 | compute의 디스크 설정에 연결 |
| `root_volume_size` | 빌드 루트 용량 | 20 GiB, 운영 볼륨이 이 값 이상 |

```bash
aws logs tail /aws/imagebuilder/arcamap-api \
  --region ap-northeast-2 --since 1h --format short
terraform -chdir=terraform/env/was output launch_template
```

판정: 이미지 생성 완료, 시작 템플릿에 새 AMI 연결. 이후 ASG의 Rolling 교체가 진행됩니다.
