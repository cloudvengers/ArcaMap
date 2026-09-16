# 공통 네트워크·보안 적용

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| VPC | 서비스의 IP 주소 범위와 통신 경로 | `10.0.0.0/16` |
| 서브넷 | 하나의 가용 영역에 배치하는 VPC 주소 범위 | 퍼블릭·API·DB × 2개 AZ |
| 라우팅 | 목적지별 다음 통신 경로 | local·IGW·NAT |
| 보안 그룹 | 자원별 인바운드·아웃바운드 허용 규칙 | ALB·API·DB 분리 |

## 현재 구성

| 항목 | 값 |
|---|---|
| 실행 위치 | `/root/protomaps/terraform/env/app` |
| Terraform / AWS Provider | `1.16.1` / `6.63.0` |
| 리전 / State | `ap-northeast-2` / 루트의 `terraform.tfstate` |
| 외부 입력 변수 | 없음 |
| 모듈 연결 | `network.vpc_id` → `security.vpc_id` |
| VPC 이름 | `arcamap-vpc` |

| 역할 | ap-northeast-2a | ap-northeast-2c | 외부 기본 경로 |
|---|---|---|---|
| 퍼블릭 | `10.0.1.0/24` | `10.0.2.0/24` | IGW |
| API | `10.0.11.0/24` | `10.0.12.0/24` | 같은 AZ의 NAT |
| DB | `10.0.21.0/24` | `10.0.22.0/24` | 없음 |

| 보안 그룹 | 인바운드 | 아웃바운드 |
|---|---|---|
| `arcamap-alb` | 전체 IPv4에서 TCP 80·443 | API 그룹의 TCP 8080 |
| `arcamap-api` | ALB 그룹에서 TCP 8080 | DB 그룹의 TCP 5432, 전체 IPv4의 TCP 443 |
| `arcamap-database` | API 그룹에서 TCP 5432 | 별도 허용 규칙 없음 |

## 적용 절차

```bash
cd /root/protomaps
aws sts get-caller-identity
terraform -chdir=terraform/env/app init -lockfile=readonly
terraform -chdir=terraform/env/app plan -out=app.tfplan
terraform -chdir=terraform/env/app apply app.tfplan
terraform -chdir=terraform/env/app output
```

| 단계 | 정상 기준 |
|---|---|
| 실행 계정 | 서비스 계정 `565725315772` |
| 변경 계획 | 기존 state 기준, 의도하지 않은 교체·삭제 없음 |
| 적용 | VPC 1개·서브넷 6개·NAT 2개·보안 그룹 3개 |
| 라우팅 | 퍼블릭→IGW, API→같은 AZ의 NAT, DB→VPC 내부 |

## 출력·후속 루트 연결

| 출력 | 내용 | 사용 |
|---|---|---|
| `vpc_id` | VPC ID | 네트워크 조회 |
| `public_subnet_ids` | AZ별 퍼블릭 서브넷 ID | ALB 배치 |
| `api_subnet_ids` | AZ별 API 서브넷 ID | ASG·Image Builder 배치 |
| `database_subnet_ids` | AZ별 DB 서브넷 ID | RDS 서브넷 그룹 |
| `alb_security_group_id` | ALB 보안 그룹 ID | 인터넷 수신·WAS 전달 |
| `api_security_group_id` | API 보안 그룹 ID | WAS·이미지 빌드 EC2 |
| `database_security_group_id` | DB 보안 그룹 ID | RDS 연결 제한 |

서브넷 출력 키: `ap-northeast-2a`·`ap-northeast-2c`.

db·was의 조회 기준: VPC `Name=arcamap-vpc`, 서브넷 `Name=arcamap-<역할>-<AZ>`, 보안 그룹 이름. 조회 시 VPC 범위를 함께 지정하며, 출력 ID를 별도 변수로 입력하지 않습니다.
