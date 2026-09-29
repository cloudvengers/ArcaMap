# Terraform 실행 구성

각 하위 폴더는 관리 대상별로 따로 실행하는 Terraform 루트입니다. 개발·운영 환경을 구분한 폴더가 아닙니다. `env`는 배포 설정과 모듈 연결을 담당하고, `modules`는 AWS 리소스의 구체적인 설정을 담당합니다.

현재 구성은 배포 전 상태입니다. `data.tf`는 이미 생성된 리소스를 조회하므로, 선행 리소스를 배포한 뒤 해당 루트의 실제 `plan`을 실행합니다.

| 실행 폴더 | 관리 대상 | 연결하는 모듈 | 선행 구성 |
|---|---|---|---|
| [network](network/) | VPC·서브넷·라우팅·보안 그룹 | `network`, `security` | 없음 |
| [database](database/) | RDS·DB 로그·경보 | `database`, `cloudwatch-log-group`, `cloudwatch-alarm` | `network` |
| [api](api/) | ALB·WAF·AMI·EC2·IAM·배포 파일·API DNS | `alb`, `image-builder`, `compute`, `s3-bucket`, 로그·경보 모듈 | `network`, `database`, 기존 ACM 인증서·DNS 역할 |
| [frontend](frontend/) | 웹·사진·로그 S3·CloudFront·WAF·웹 DNS | `s3-bucket`, `cloudfront` | 기존 지도 버킷·ACM 인증서·DNS 역할 |
| [monitoring](monitoring/) | API·웹 통합 대시보드 | `cloudwatch-dashboard` | `api`, `frontend` |

`network → database → api → monitoring` 순서로 내부 조회 대상이 준비됩니다. `frontend`는 네트워크·DB 루트에 의존하지 않지만, 대시보드보다 먼저 배포해야 합니다.

## 파일을 찾는 기준

| 파일 | 역할 |
|---|---|
| `main.tf` | 해당 루트의 주요 모듈 연결 |
| `data.tf` | 기존 AWS 리소스 조회 |
| `versions.tf` | Terraform·AWS 공급자 버전 요구 사항 |
| `providers.tf` | 리전·DNS 관리 역할 등 공급자 접속 설정 |
| `variables.tf` | 실행 시 받는 입력값 선언 |
| `outputs.tf` | 실행 결과로 반환할 값 |
| `monitoring.tf` | 해당 서비스의 로그·Agent·경보 설정 |
| `dns.tf` | API·웹 DNS 레코드 |
| `iam.tf` | 운영·이미지 빌드 EC2 권한 |
| `deployment.tf` | API 배포 객체와 DB 접속 정보 저장 |
| `image-builder.tf` | API 이미지 빌드 모듈 연결 |
| `alb.tf` | API ALB·WAF 모듈 연결 |
| `storage.tf` | 웹·사진·접근 로그 버킷 모듈 연결 |

필요한 역할이 있는 루트에만 해당 파일을 둡니다. DB·API 로그와 경보는 각각 `database/monitoring.tf`, `api/monitoring.tf`에서 관리하고, `monitoring` 루트는 통합 대시보드를 관리합니다.

예를 들어 네트워크 구문 검사는 저장소 루트에서 `terraform -chdir=env/network validate`로 실행합니다. 자세한 AWS 리소스 위치는 [모듈 안내](../modules/README.md)를 참고하세요.

각 루트의 `terraform.tfvars`는 해당 폴더에서만 읽습니다. `database`의 비밀번호 입력값은 `api`에 자동으로 전달되지 않습니다.
