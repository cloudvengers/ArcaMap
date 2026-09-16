# Terraform 구성

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 실행 루트 | 독립적으로 init·plan·apply를 실행하는 작업 단위 | app·db·was·web |
| 하위 모듈 | 루트가 호출하는 자원 구성 단위 | 공통 모듈 10개 |
| State | Terraform 주소와 실제 AWS 자원의 연결 정보 | 루트별 `terraform.tfstate` |
| 데이터 소스 | 기존 자원 조회 | VPC·서브넷·보안 그룹·RDS·인증서 |
| `import` | 기존 자원을 Terraform 주소에 등록 | 콘솔에서 만든 WAF·로그 자원 3개 |
| Provider 별칭 | 같은 Provider의 별도 계정·리전 설정 | `aws.dns`로 DNS 계정 역할 사용 |
| Write-only 입력 | 자원에 쓰되 state·plan에 값을 저장하지 않는 인수 | RDS 비밀번호·Secret 내용 |

## 실행 환경

| 항목 | 값 |
|---|---|
| 작업 위치 | `/root/protomaps` |
| Terraform / AWS Provider | `1.16.1` / `6.63.0` |
| 서비스 리전 | `ap-northeast-2` |
| 가용 영역 | `ap-northeast-2a`·`ap-northeast-2c` |
| 서비스 계정 / DNS 계정 | `565725315772` / `438465145630` |
| State | 각 루트의 로컬 파일, 원격 backend 없음 |
| 공급자 잠금 | 각 루트의 `.terraform.lock.hcl` |

## 실행 루트

| 문서 | 실행 위치 | 관리 자원 | 선행 조건 |
|---|---|---|---|
| `env/app.md` | `terraform/env/app` | VPC·서브넷·라우팅·NAT·보안 그룹 | 서비스 계정 권한 |
| `env/db.md` | `terraform/env/db` | RDS·DB 로그·경보 | app 적용 |
| `env/was.md` | `terraform/env/was` | IAM·배포 S3·Secret·ALB·AMI·ASG·API DNS·로그·경보 | app·db 적용, API 인증서·배포 아카이브 |
| `env/web.md` | `terraform/env/web` | 정적·사진·로그 S3·CloudFront·WAF·웹 DNS | 기존 지도 버킷·웹 인증서·DNS 역할 |

```text
app → db → was
web: 독립 적용
```

루트 간 state 공유 없음. db·was는 이름·태그로 기존 자원을 조회하며, 선행 루트를 자동 실행하지 않습니다.

## 공통 모듈

| 문서 | 호출 루트 | 관리 대상 |
|---|---|---|
| `modules/network.md` | app | VPC·서브넷·IGW·NAT·라우팅 |
| `modules/security.md` | app | ALB·API·DB 보안 그룹 |
| `modules/database.md` | db | 비공개 Multi-AZ PostgreSQL |
| `modules/alb.md` | was | HTTPS 리스너·대상 그룹·ALB 로그 전달 |
| `modules/image-builder.md` | was | OS·API 설치·운영 AMI 생성 |
| `modules/compute.md` | was | 시작 템플릿·ASG·CPU 확장 정책 |
| `modules/s3-bucket.md` | was·web | 비공개 버킷·암호화·버전·만료 설정 |
| `modules/cloudfront.md` | web | 캐시·OAC·오리진 정책·접근 로그·WAF |
| `modules/cloudwatch-log-group.md` | db·was | 로그 그룹·보존 기간 |
| `modules/cloudwatch-alarm.md` | db·was | 지표 경보·임계값·평가 기간 |

## 현재 배포 구성

| 대상 | 설정 |
|---|---|
| 웹 / API | `https://arcamap.app` / `https://api.arcamap.app` |
| 웹 요청 | CloudFront → 정적·지도·사진 S3 |
| 웹 WAF | 기존 Web ACL 가져오기 완료, 관리형 규칙 그룹 4개 Count·요청 로그 14일 보존 |
| API 요청 | ALB:443 → WAS:8080 → RDS:5432 |
| WAS 배포 | 소스 5개 파일 → S3 아카이브 → API 포함 AMI → ASG 교체 |
| 이미지 / 상태 검사 | 레시피 `1.1.2`, ASG `ELB` |
| DB 인증 | 서비스 시작 시 `arcamap/api/database` Secret 조회 |
| DB 보호 | Multi-AZ·암호화·자동 백업 3일·삭제 보호 |
| 경보 알림 | `actions_enabled = false`, 수신 대상 없음 |
| 교체 정상 비율 | 최소 0%·최대 100%, 교체 중 API 중단 가능 |

## 적용 순서

| 순서 | 작업 | 완료 기준 |
|---|---|---|
| 1 | 실행 계정·루트의 기존 state 확인 | 서비스 계정과 관리 자원 일치 |
| 2 | app에서 init → plan → apply | VPC·서브넷·보안 그룹 출력 |
| 3 | db에서 init → plan → apply | RDS `available`, 비공개·5432 |
| 4 | API 아카이브 생성, was 입력 확정 후 init → plan → apply | AMI 출력, ASG `InService`, ALB `healthy` |
| 독립 | web에서 init → plan → apply, 웹 빌드·S3 업로드·캐시 갱신 | 웹 200, 지도 Range 206 |

기존 자원을 새 state에서 다시 생성하면 이름 충돌·중복 생성 가능. 변경 계획에서 교체·삭제 대상을 확인합니다.
