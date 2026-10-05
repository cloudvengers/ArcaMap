# Terraform 모듈

`modules`는 AWS 리소스를 구성하는 모듈 11개를 포함합니다. [환경별 구성](../env/README.md)에서 필요한 모듈을 연결하고 입력값을 전달합니다.

| 모듈 | 구성 대상 | 사용 환경 |
|---|---|---|
| [network](network/README.md) | VPC, 공개·사설 서브넷, Internet Gateway, NAT Gateway와 라우팅 | `network` |
| [security](security/README.md) | ALB·API·DSQL VPC 엔드포인트·Image Builder 보안 그룹 | `network` |
| [database](database/README.md) | Aurora DSQL 클러스터와 VPC 엔드포인트 | `database` |
| [alb](alb/README.md) | 공개 ALB, 대상 그룹, API WAF와 로그 | `api` |
| [compute](compute/README.md) | API 시작 템플릿, ASG, 자동 조정과 인스턴스 교체 | `api` |
| [image-builder](image-builder/README.md) | Image Builder 파이프라인과 AMI 수명 주기 | `api` |
| [s3-bucket](s3-bucket/README.md) | S3 버킷, 암호화, 버전 관리와 수명 주기 | `api`, `frontend` |
| [cloudfront](cloudfront/README.md) | CloudFront, OAC, 캐시, 보안 응답 헤더, WAF와 로그 | `frontend` |
| [cloudwatch-log-group](cloudwatch-log-group/README.md) | 로그 그룹과 보존 기간 | `api` |
| [cloudwatch-alarm](cloudwatch-alarm/README.md) | 지표 경보와 SNS 알림 연결 | `api`, `database` |
| [cloudwatch-dashboard](cloudwatch-dashboard/README.md) | 지표·로그·경보 대시보드 | `monitoring` |

각 모듈의 `main.tf`와 용도별 `.tf` 파일은 리소스를 정의합니다. `variables.tf`는 입력을, `outputs.tf`는 다른 구성에 전달할 값을 정의합니다.

모든 모듈은 Terraform `1.16.1`과 AWS Provider `6.63.0`을 사용합니다.
