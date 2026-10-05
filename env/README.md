# Terraform 환경

`env`는 관리 대상별 Terraform 구성을 포함합니다. 각 환경은 입력값과 리소스 조회 결과를 [공통 모듈](../modules/README.md)에 전달합니다.

기본 리전은 서울 `ap-northeast-2`입니다. CloudFront의 ACM 인증서와 WAF는 `us-east-1`을 사용합니다. 모든 환경은 Terraform `1.16.1`과 AWS Provider `6.63.0`을 사용합니다.

## 환경별 역할

| 환경 | 관리 대상 |
|---|---|
| [network](network/README.md) | VPC, 공개·사설 서브넷, NAT Gateway, 보안 그룹과 SNS |
| [database](database/README.md) | Aurora DSQL, VPC 엔드포인트와 연결 수 경보 |
| [api](api/README.md) | ALB, API WAF, DNS, IAM, ASG, Image Builder, 배포 S3와 경보 |
| [frontend](frontend/README.md) | 정적 파일·사진·지도·로그 S3, CloudFront, WAF와 DNS |
| [monitoring](monitoring/README.md) | 지표·로그·경보 통합 대시보드 |
| [bootstrap](bootstrap/) | DSQL 관리용 임시 EC2와 전용 IAM 역할 |
| [backup](backup/) | AWS Backup 볼트, KMS 키와 백업·복원 IAM 역할 |

## 환경 간 연결

네트워크와 SNS는 이름·태그로 조회합니다. 모니터링은 ASG, ALB, WAF와 로그 그룹을 이름·접두사로 조회합니다. 리소스 식별자와 접속 정보는 각 환경의 `terraform.tfvars` 또는 `terraform.tfvars.json`에 지정합니다.

| 제공 환경 | 받는 환경 | 전달 값 |
|---|---|---|
| `database` | `api` | `database`의 클러스터·리전·접속 정보 |
| `database` | `monitoring` | `database.cluster_id` → `dsql_cluster_identifier` |
| `database` | `bootstrap` | `database.cluster_arn` → `cluster_arn` |
| `database` | `backup` | `database.cluster_arn` → `dsql_cluster_arn` |
| `api` | `bootstrap` | `deployment_bucket.id` → `deployment_bucket` |
| `api` | `backup` | `ec2_api_role_arn`, `deployment_bucket.arn` |
| `frontend` | `backup` | `s3_bucket_arns`의 정적 파일·사진·지도·로그 버킷 ARN |

## DSQL 관리용 임시 환경

[bootstrap/main.tf](bootstrap/main.tf)는 사설 서브넷의 임시 인스턴스와 DSQL 관리 권한을 구성합니다.

| 항목 | 설정 |
|---|---|
| 인스턴스 이름 | `arcamap-bootstrap` |
| 인스턴스 유형 | `t3.small` |
| 운영체제 이미지 | Canonical Ubuntu Server 26.04, `x86_64` |
| 서브넷 | `ap-northeast-2a`의 API 사설 서브넷 |
| 보안 그룹 | `arcamap-imagebuilder` |
| 루트 볼륨 | 암호화한 `gp3` 20GiB, 인스턴스 종료 시 삭제 |
| 공인 IP | 할당 비활성화 |
| 인스턴스 메타데이터 | IMDSv2 필수 |

EC2 역할 `arcamap-bootstrap-ec2`에는 Session Manager, 지정한 S3 객체 읽기와 DSQL 전용 역할 전환 권한을 부여합니다. `arcamap-bootstrap-admin`은 대상 클러스터의 `dsql:DbConnectAdmin`을, `arcamap-bootstrap-writer`는 `dsql:DbConnect`를 사용합니다.

입력은 클러스터 ARN `cluster_arn`, 파일 저장 버킷 `deployment_bucket`, 작업 파일 경로 `bundle_path`입니다. 출력은 인스턴스 ID `instance_id`와 전용 역할 ARN `database_roles`입니다.

## 백업과 복원

`backup` 환경은 온디맨드 백업에 사용하는 `arcamap-backup` 볼트와 전용 KMS 키를 구성합니다. 볼트와 키에는 삭제 방지를 적용합니다. KMS 키는 자동 교체를 활성화하며 삭제 대기 기간은 30일입니다.

백업 역할은 `arcamap-backup-backup`, 복원 역할은 `arcamap-backup-restore`입니다. 대상은 DSQL 클러스터, API EC2와 S3 버킷 5종입니다.

| 입력 | 내용 |
|---|---|
| `dsql_cluster_arn` | 대상 DSQL 클러스터 ARN |
| `api_instance_arns` | 대상 API EC2 ARN 집합 |
| `api_restore_role_arn` | 복원 EC2에 전달할 API IAM 역할 ARN |
| `s3_bucket_arns` | `web`, `photo`, `maps`, `logs`, `deploy` 버킷 ARN |
| `source_kms_key_arns` | 원본과 복원 대상에 사용하는 KMS 키 ARN |
| `existing_backup_opt_in_preferences` | 계정의 리소스 유형별 백업 선택 설정 |
| `existing_backup_management_preferences` | 계정의 리소스 유형별 백업 관리 설정 |

프런트엔드의 `static`, `photos`, `maps`, `cloudfront_logs` 버킷은 각각 `web`, `photo`, `maps`, `logs`에 연결합니다. API 배포 버킷은 `deploy`에 연결합니다. EC2를 백업 대상으로 지정할 때는 암호화한 원본 EBS의 KMS 키 ARN도 입력합니다.

리전 설정은 입력한 백업 선택 설정에 `DSQL=true`를 적용합니다. 리소스 관리 설정은 입력값을 사용합니다.

[backup/outputs.tf](backup/outputs.tf)는 볼트, KMS 키, 백업·복원 역할과 대상 ARN을 반환합니다. `on_demand_lifecycle.delete_after_days` 출력값은 온디맨드 백업의 7일 보존 입력값입니다.
