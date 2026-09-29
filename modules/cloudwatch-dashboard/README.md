# CloudWatch 대시보드 모듈

ASG·EC2·ALB·WAF 지표, 서비스 경보 상태, Logs Insights 조회 패널을 하나의 대시보드에 표시합니다. 조회 대상 식별 정보는 `env/monitoring` 루트에서 전달합니다.

| 파일 | 역할 |
|---|---|
| [main.tf](main.tf) | 지표·로그 패널과 대시보드 위젯 정의 |
| [variables.tf](variables.tf) | ASG·ALB·WAF·경보·로그 그룹 입력 선언 |
| [outputs.tf](outputs.tf) | 대시보드 이름·ARN 반환 |
| [versions.tf](versions.tf) | AWS 공급자 요구 사항 |
