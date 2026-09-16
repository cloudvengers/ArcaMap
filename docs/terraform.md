# 인프라 구축

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 루트 모듈 | 독립적으로 init·plan·apply를 실행하는 Terraform 작업 단위 | app / db / was / web |
| 하위 모듈 | 루트에서 호출하는 자원 구성 단위 | network, security, compute 등 |
| State | Terraform 자원 주소와 실제 AWS 자원의 연결 정보 | 루트별 로컬 `terraform.tfstate` |
| 데이터 소스 | 기존 자원 조회. 조회 대상 생성은 별도 작업 | VPC·서브넷·RDS·인증서 조회 |
| VPC | IP 주소 범위와 내부 통신 경로를 구성하는 분리된 네트워크 | `10.0.0.0/16` |
| 서브넷 | VPC 주소 범위의 일부. 하나의 가용 영역에 배치 | 퍼블릭·API·DB × 2개 AZ |
| 라우팅 테이블 | 목적지 주소에 따른 다음 통신 경로 | local / IGW / NAT |
| 보안 그룹 | 리소스의 인바운드·아웃바운드 허용 규칙 | ALB·API·DB 분리 |

## 실행 환경

| 항목 | 값 |
|---|---|
| 작업 위치 | `/root/protomaps` |
| Terraform | `1.16.1` |
| AWS Provider | `6.63.0` · 루트별 `.terraform.lock.hcl` |
| 서비스 리전 | `ap-northeast-2` |
| CloudFront 인증서 | 기존 `us-east-1` ACM 인증서 |
| ALB 인증서 | 기존 `ap-northeast-2` ACM 인증서 |
| DNS | 기존 공개 호스팅 영역, `aws.dns`의 AssumeRole |
| 기존 지도 버킷 | `protomaps-565725315772-ap-northeast-2-an` |

## 자원 소유 범위

| 루트 | 생성·관리 대상 | 선행 조건 | 주요 출력 |
|---|---|---|---|
| app | VPC·서브넷·라우팅·NAT·보안 그룹 | AWS 자원 생성 권한 | `vpc_id`, 서브넷·보안 그룹 ID |
| db | RDS·DB 로그·경보 | app 적용 | `database`, `log_groups` |
| was | IAM·배포 S3·Secret·ALB·Image Builder·AMI·ASG·API DNS·로그·경보 | app·db 적용, API 인증서, 배포 아카이브 | `alb`, `api_url`, `autoscaling_group`, `launch_template`, `built_image` |
| web | 정적·사진·로그 S3, CloudFront·OAC·웹 DNS | 지도 버킷, 웹 인증서, DNS 역할 | `cloudfront`, `frontend_url`, `s3_buckets` |

- 적용 의존성: `app → db → was`
- `web`: app·db·was와 독립 적용
- DNS 역할·호스팅 영역·도메인 등록·인증서 검증 CNAME: 기존 자원
- 지도 버킷: 기존 버킷 조회, CloudFront 읽기 정책은 web에서 관리

## VPC·서브넷

| 용도 | ap-northeast-2a | ap-northeast-2c | 배치 자원 |
|---|---|---|---|
| 퍼블릭 | `10.0.1.0/24` | `10.0.2.0/24` | ALB·NAT Gateway |
| API | `10.0.11.0/24` | `10.0.12.0/24` | WAS·Image Builder EC2 |
| DB | `10.0.21.0/24` | `10.0.22.0/24` | RDS |

| 설정 | 값 |
|---|---|
| VPC 이름 | `arcamap-vpc` |
| DNS support / hostnames | 모두 활성화 |
| 서브넷의 퍼블릭 IPv4 자동 할당 | 모두 비활성화 |
| NAT Gateway | 퍼블릭 서브넷에 AZ별 1개, EIP 사용 |

퍼블릭 서브넷: Internet Gateway로 향하는 직접 경로가 있는 서브넷.

프라이빗 서브넷: Internet Gateway로 향하는 직접 경로가 없는 서브넷. API는 NAT로 외부 통신, DB는 VPC 내부 통신만 허용하는 라우팅 구성.

## 라우팅

| 서브넷 | 목적지 | 다음 경로 |
|---|---|---|
| 전체 | `10.0.0.0/16` | `local` |
| 퍼블릭 | `0.0.0.0/0` | Internet Gateway |
| API — 2a | `0.0.0.0/0` | 2a NAT Gateway |
| API — 2c | `0.0.0.0/0` | 2c NAT Gateway |
| DB | 외부 기본 경로 | 없음 |

| 용어 | 의미 |
|---|---|
| `local` | VPC 내부 주소 간 통신 경로 |
| `0.0.0.0/0` | 모든 IPv4 목적지를 포함하는 기본 경로 |
| 경로 우선순위 | 목적지와 일치하는 주소 범위가 가장 구체적인 경로 우선 |
| Internet Gateway | VPC와 인터넷 사이의 통신 관문 |
| NAT Gateway | 사설 IPv4 출발지 주소를 변환하여 외부 통신 제공 |

```text
인터넷 → IGW → ALB:443 → WAS:8080 → RDS:5432
WAS → 같은 AZ의 NAT → IGW → 외부 HTTPS:443
WAS → local → RDS:5432
```

## 보안 그룹

라우팅: 패킷 전달 경로 결정. 보안 그룹: 통신 허용 여부 결정.

| 보안 그룹 | 방향 | 상대 | 프로토콜·포트 |
|---|---|---|---|
| `arcamap-alb` | 인바운드 | `0.0.0.0/0` | TCP 80·443 |
| `arcamap-alb` | 아웃바운드 | API 보안 그룹 | TCP 8080 |
| `arcamap-api` | 인바운드 | ALB 보안 그룹 | TCP 8080 |
| `arcamap-api` | 아웃바운드 | DB 보안 그룹 | TCP 5432 |
| `arcamap-api` | 아웃바운드 | `0.0.0.0/0` | TCP 443 |
| `arcamap-database` | 인바운드 | API 보안 그룹 | TCP 5432 |

- 보안 그룹 참조: 교체되는 EC2의 개별 IP 대신 상대 보안 그룹을 허용 대상으로 지정
- Stateful: 허용된 연결의 응답 트래픽은 역방향 허용 규칙 없이 통과
- EC2 관리 접속: SSM 사용, SSH 인바운드 규칙 없음

## 입력·권한

| 대상 | 입력 |
|---|---|
| app | 별도 변수 없음 |
| db | 엔진·인스턴스·용량·DB 계정·비밀번호·최종 스냅샷 이름 |
| was | API 도메인·DNS 역할·프로파일·EC2·ASG·이미지 버전·기존 DB 비밀번호 |
| web | 웹 도메인·DNS 역할·캐시 TTL·가격 등급·로그 보존 기간 |

- 일반 입력: 각 루트의 `terraform.tfvars`
- `db_password`: db·was에 동일한 운영 RDS 비밀번호 사용
- `TF_VAR_db_password`: 대화형 비밀번호 입력을 통한 환경 변수 공급 가능. 같은 변수가 `terraform.tfvars`에 있으면 파일 값 우선
- DB·Secret 쓰기: ephemeral 변수와 write-only 인수 사용, 비밀번호의 state·plan 저장 제외
- `password_wo_version`, `secret_string_wo_version`: 현재 각각 `1`; 실제 비밀번호 변경 시 값과 버전의 동시 관리 필요
- 운영 EC2 역할: SSM·CloudWatch·지정 Secret 조회
- Image Builder 역할: 운영 공통 권한 + 이미지 생성·지정 배포 객체 읽기·시스템 로그 조회

## 적용 절차

### 1. 실행 계정 확인

```bash
aws sts get-caller-identity
terraform version
```

판정: 서비스 계정·실행 역할 일치, Terraform `1.16.1`.

### 2. 공통 네트워크 적용

```bash
terraform -chdir=terraform/env/app init -lockfile=readonly
terraform -chdir=terraform/env/app plan -out=app.tfplan
terraform -chdir=terraform/env/app apply app.tfplan
```

판정: VPC·서브넷·보안 그룹 출력 생성, 의도하지 않은 교체·삭제 없음.

### 3. DB·WAS·WEB 적용

| 순서 | 작업 | 절차 |
|---|---|---|
| 1 | DB 생성·확인 | `env/db`에서 init → plan → apply, RDS available·5432 확인 |
| 2 | API 아카이브·이미지 생성·ASG 반영 | `was/.artifacts/was.tar.gz` 생성 → 이미지 버전 지정 → `env/was` 적용 → ASG·ALB 상태 확인 |
| 독립 | CloudFront·S3 생성·웹 업로드 | `env/web` 적용 → 운영 URL로 웹 빌드 → 정적 S3 업로드 → HTML 캐시 갱신 |

## 네트워크 점검

```bash
arcamap_vpc_id="$(terraform -chdir=terraform/env/app output -raw vpc_id)"

aws ec2 describe-route-tables \
  --region ap-northeast-2 \
  --filters "Name=vpc-id,Values=$arcamap_vpc_id" \
  --query 'RouteTables[].{ID:RouteTableId,Subnets:Associations[].SubnetId,Routes:Routes}'

aws ec2 describe-security-groups \
  --region ap-northeast-2 \
  --filters "Name=vpc-id,Values=$arcamap_vpc_id" \
  --query 'SecurityGroups[].{Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}'
```

| 점검 | 정상 기준 |
|---|---|
| 퍼블릭 기본 경로 | IGW 참조 |
| API 기본 경로 | 같은 AZ의 NAT 참조 |
| DB 라우팅 | VPC 내부 경로만 존재 |
| 경로 상태 | `active` |
| 보안 그룹 | 위 허용 규칙과 일치 |

## State 관리

| 항목 | 처리 |
|---|---|
| 저장 위치 | 각 루트의 `terraform.tfstate` |
| 변경 계획 | 같은 루트의 state와 실행 계정 기준으로 검토 |
| 신규 state 적용 | 기존 자원이 있으면 중복 생성·이름 충돌 가능; 소유 관계 확인 필요 |
| 원격 상태 | 현재 backend 구성 없음 |
| 과거 단일 루트 | 현재 네 루트로의 state 이전 완료 기록 없음 |
