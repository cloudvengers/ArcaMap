# 통합 모니터링 실행 구성

배포된 API·웹 리소스의 지표·경보·로그를 CloudWatch 대시보드에 연결합니다. 서비스 로그와 경보를 생성하는 코드는 `database/monitoring.tf`, `api/monitoring.tf`에 있습니다.

| 파일 | 역할 |
|---|---|
| [data.tf](data.tf) | ASG·ALB·대상 그룹·웹 ACL·로그 그룹 조회 |
| [main.tf](main.tf) | 조회 결과와 서비스 경보를 대시보드 모듈에 전달 |
| [providers.tf](providers.tf) | AWS 리전 접속 구성 |
| [versions.tf](versions.tf) | Terraform·AWS 공급자 버전 요구 사항 |
| [outputs.tf](outputs.tf) | 대시보드 이름·ARN 반환 |

`api`, `frontend`를 먼저 배포해야 실제 `plan`에서 조회 대상을 찾을 수 있습니다. 구성 관계는 [실행 구성 안내](../README.md), 위젯 정의는 [대시보드 모듈](../../modules/cloudwatch-dashboard/)을 참고하세요.
