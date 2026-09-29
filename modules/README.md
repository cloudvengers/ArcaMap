# Terraform 리소스 모듈

AWS 리소스를 역할별로 정의합니다. [실행 구성](../env/README.md)에서 필요한 모듈을 연결하고 입력값을 전달합니다. 모듈은 한 단계로 유지하며, WAF·로그처럼 관련된 구성은 같은 모듈 안에서 파일로 구분합니다.

| 모듈 | 정의하는 리소스 | 주요 리소스 파일 | 사용하는 실행 폴더 |
|---|---|---|---|
| [network](network/) | VPC·서브넷·라우팅·IGW·NAT | `main.tf` | `env/network` |
| [security](security/) | ALB·API·DB 보안 그룹과 통신 규칙 | `main.tf` | `env/network` |
| [database](database/) | RDS·DB 서브넷 그룹 | `main.tf` | `env/database` |
| [alb](alb/) | ALB·리스너·대상 그룹·API WAF·로그 전달 | `main.tf`, `waf.tf`, `logs.tf` | `env/api` |
| [compute](compute/) | EC2 시작 템플릿·ASG·확장 정책 | `launch-template.tf`, `main.tf`, `scaling.tf` | `env/api` |
| [image-builder](image-builder/) | 기반 AMI 조회·Agent/API 설치·검증·AMI 빌드 | `data.tf`, `agent-components.tf`, `api-components.tf`, `main.tf` | `env/api` |
| [s3-bucket](s3-bucket/) | S3·공개 접근 차단·소유권·암호화·수명 주기 | `main.tf` | `env/api`, `env/frontend` |
| [cloudfront](cloudfront/) | CloudFront·OAC·캐시·WAF·로그 전달·S3 접근 정책 | `main.tf`, `cache.tf`, `waf.tf`, `logs.tf`, `permissions.tf` | `env/frontend` |
| [cloudwatch-log-group](cloudwatch-log-group/) | 로그 그룹·보존 기간 | `main.tf` | `env/database`, `env/api` |
| [cloudwatch-alarm](cloudwatch-alarm/) | 지표 경보 | `main.tf` | `env/database`, `env/api` |
| [cloudwatch-dashboard](cloudwatch-dashboard/) | 통합 지표·경보·로그 대시보드 | `main.tf` | `env/monitoring` |

각 모듈의 `variables.tf`는 입력값, `outputs.tf`는 반환값, `versions.tf`는 공급자 요구 사항을 정의합니다. `compute/moved.tf`는 이전 인덱스 주소를 현재 주소로 연결하는 상태 호환 선언입니다.

서비스별 로그·경보 기준은 `env/database/monitoring.tf`, `env/api/monitoring.tf`에서 정합니다. WAF 로그 그룹과 전달 설정은 보호 대상의 `alb/logs.tf`, `cloudfront/logs.tf`에 둡니다.
